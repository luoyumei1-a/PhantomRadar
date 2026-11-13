"""Bounded, free-space FMCW link-budget calculations in dB.

These are analytical predictions, not measured overload or attack labels. The
radar equation requires its usual far-field, scattering and propagation
assumptions. A limiting input power must be supplied from a relevant measured
or documented configuration: out-of-band compression, ADC full scale and
damage ratings are not interchangeable thresholds.
"""
from __future__ import annotations
import math

LIGHT_SPEED_M_S = 299_792_458.0
PEAK_GEOMETRY_COEFFICIENTS = {
    'triangular_trihedral': math.pi / 12,
    'square_trihedral': math.pi / 3,
    'normal_incidence_circular_plate': math.pi**3 / 16,
}


def _finite(value, name):
    if isinstance(value, bool):
        raise ValueError(f'{name} must be a finite scalar')
    value = float(value)
    if not math.isfinite(value):
        raise ValueError(f'{name} must be a finite scalar')
    return value


def _positive(value, name):
    value = _finite(value, name)
    if value <= 0:
        raise ValueError(f'{name} must be positive')
    return value


def fractional_nominal_power_dbm(nominal_dbm, fraction=0.9):
    """Scale nominal RF power in linear units, retaining the nominal power basis.

    This is a budget conversion, not a command encoding or measured output.
    """
    nominal = _finite(nominal_dbm, 'nominal_dbm')
    fraction = _positive(fraction, 'fraction')
    if fraction > 1:
        raise ValueError('fraction must be at most one')
    return nominal + 10 * math.log10(fraction)


def free_space_path_loss_db(frequency_hz, distance_m):
    """One-way Friis free-space path loss; no near-field validity guarantee."""
    frequency = _positive(frequency_hz, 'frequency_hz')
    distance = _positive(distance_m, 'distance_m')
    return 20*math.log10(4*math.pi*distance*frequency/LIGHT_SPEED_M_S)


def direct_input_dbm(tx_dbm, tx_gain_dbi, rx_gain_dbi, frequency_hz, distance_m, loss_db=0):
    """Received power for a direct, one-way propagating emitter."""
    values=[_finite(v,n) for v,n in ((tx_dbm,'tx_dbm'),(tx_gain_dbi,'tx_gain_dbi'),(rx_gain_dbi,'rx_gain_dbi'),(loss_db,'loss_db'))]
    return values[0]+values[1]+values[2]-free_space_path_loss_db(frequency_hz,distance_m)-values[3]


def direct_source_requirements(input_limit_dbm, tx_gain_dbi, rx_gain_dbi,
        frequency_hz, distance_m, loss_db=0):
    """Conducted power and EIRP reaching a supplied input boundary.

    This inverts the same one-way path used by a relay's outgoing hop.
    The source's antenna gain is included exactly once in EIRP. No relay
    loop gain or receive/transmit isolation constraint applies to this direct
    source calculation. RF, timing, IF filtering and propagation assumptions
    must still be matched before interpreting the result physically.
    """
    boundary = _finite(input_limit_dbm, 'input_limit_dbm')
    antenna_gain = _finite(tx_gain_dbi, 'tx_gain_dbi')
    transfer = direct_input_dbm(0, antenna_gain, rx_gain_dbi,
        frequency_hz, distance_m, loss_db)
    required = boundary - transfer
    eirp = required + antenna_gain
    return dict(required_conducted_dbm=required,
        required_conducted_mw=10**(required/10),
        required_eirp_dbm=eirp, required_eirp_mw=10**(eirp/10),
        outgoing_transfer_db=transfer,
        interpretation='conditional_free_space_boundary_not_observed_attack')


def monostatic_echo_dbm(tx_dbm, tx_gain_dbi, rx_gain_dbi, frequency_hz, rcs_m2, distance_m, loss_db=0):
    """Two-way monostatic radar equation for an assumed target RCS."""
    frequency=_positive(frequency_hz,'frequency_hz');sigma=_positive(rcs_m2,'rcs_m2');distance=_positive(distance_m,'distance_m')
    values=[_finite(v,n) for v,n in ((tx_dbm,'tx_dbm'),(tx_gain_dbi,'tx_gain_dbi'),(rx_gain_dbi,'rx_gain_dbi'),(loss_db,'loss_db'))]
    wavelength=LIGHT_SPEED_M_S/frequency
    return values[0]+values[1]+values[2]+20*math.log10(wavelength)+10*math.log10(sigma)-30*math.log10(4*math.pi)-40*math.log10(distance)-values[3]


def threshold_rcs_dbsm(input_limit_dbm, tx_dbm, tx_gain_dbi, rx_gain_dbi, frequency_hz, distance_m, loss_db=0):
    """Analytical RCS needed to reach a supplied input-power limit.

    The value is a conditional boundary, not a hardware diagnosis. The caller
    must retain the input-limit source, frequency offset, gain and uncertainty.
    """
    reference=monostatic_echo_dbm(tx_dbm,tx_gain_dbi,rx_gain_dbi,frequency_hz,1,distance_m,loss_db)
    return _finite(input_limit_dbm,'input_limit_dbm')-reference


def bounded_relay_input_dbm(tx_dbm, victim_tx_gain_dbi, victim_rx_gain_dbi,
        relay_rx_gain_dbi, relay_tx_gain_dbi, amplifier_gain_db,
        relay_linear_output_max_dbm, frequency_hz, incoming_distance_m,
        outgoing_distance_m, incoming_loss_db=0, outgoing_loss_db=0,
        isolation_db=None, stability_margin_db=0):
    """Two-hop amplify-and-forward link with finite output and optional isolation.

    Fixed amplifier gain gives R1^-2 R2^-2 received power while linear. A
    bounded fixed relay output leaves only the outgoing R2^-2 attenuation.
    Gain must not exceed measured antenna isolation minus a declared margin;
    this is a necessary engineering bound, not a complete stability proof.
    """
    gain=_finite(amplifier_gain_db,'amplifier_gain_db')
    maximum=_finite(relay_linear_output_max_dbm,'relay_linear_output_max_dbm')
    margin=_finite(stability_margin_db,'stability_margin_db')
    if margin < 0:
        raise ValueError('stability_margin_db must be nonnegative')
    if isolation_db is not None and gain > _finite(isolation_db,'isolation_db')-margin:
        raise ValueError('amplifier gain exceeds declared isolation minus stability margin')
    incoming=direct_input_dbm(tx_dbm,victim_tx_gain_dbi,relay_rx_gain_dbi,
        frequency_hz,incoming_distance_m,incoming_loss_db)
    requested=incoming+gain
    output=min(requested,maximum)
    returned=direct_input_dbm(output,relay_tx_gain_dbi,victim_rx_gain_dbi,
        frequency_hz,outgoing_distance_m,outgoing_loss_db)
    return dict(relay_input_dbm=incoming,requested_linear_output_dbm=requested,
        bounded_output_dbm=output,output_limited=requested>maximum,
        victim_input_dbm=returned,amplifier_gain_db=gain,
        interpretation='conditional_free_space_link_budget_not_observed_overload')


def far_field_peak_rcs_envelope_m2(distance_m, geometry):
    """Ideal peak physical-optics envelope subject to the Fraunhofer constraint.

    This combines each stated PEC geometry's broadside peak RCS and its
    aperture's far-field constraint. It is not a universal bound on arbitrary
    scatterers, an orientation-independent response, or a near-field model.
    """
    distance = _positive(distance_m, 'distance_m')
    if geometry not in PEAK_GEOMETRY_COEFFICIENTS:
        raise ValueError('unsupported peak scattering geometry')
    return PEAK_GEOMETRY_COEFFICIENTS[geometry] * distance**2


def passive_envelope_crossing_m(input_limit_dbm, tx_dbm, tx_gain_dbi,
        rx_gain_dbi, frequency_hz, geometry, loss_db=0):
    """Formal distance intersection of R^2 envelope and R^4 required RCS.

    A positive formal intersection does not establish that all aperture and
    physical-optics approximations remain valid at that distance.
    """
    coefficient = far_field_peak_rcs_envelope_m2(1, geometry)
    required_at_one_m = 10**(threshold_rcs_dbsm(input_limit_dbm, tx_dbm,
        tx_gain_dbi, rx_gain_dbi, frequency_hz, 1, loss_db) / 10)
    return math.sqrt(coefficient / required_at_one_m)


def relay_gain_headroom_db(input_limit_dbm, tx_dbm, victim_tx_gain_dbi,
        victim_rx_gain_dbi, relay_rx_gain_dbi, relay_tx_gain_dbi,
        device_gain_cap_db, output_cap_dbm, isolation_db, stability_margin_db,
        frequency_hz, incoming_distance_m, outgoing_distance_m,
        incoming_loss_db=0, outgoing_loss_db=0):
    """Finite two-hop gain budget with output and isolation limits.

    Isolation and margin must be supplied explicitly. Catalog stage gains and
    an output-P1dB operating cap are conditional budget parameters, not a
    measured stable cascade or an observed receiver compression event.
    """
    margin = _finite(stability_margin_db, 'stability_margin_db')
    if margin < 0:
        raise ValueError('stability_margin_db must be nonnegative')
    device_cap = _finite(device_gain_cap_db, 'device_gain_cap_db')
    isolation_cap = _finite(isolation_db, 'isolation_db') - margin
    output_cap = _finite(output_cap_dbm, 'output_cap_dbm')
    boundary = _finite(input_limit_dbm, 'input_limit_dbm')
    incoming = direct_input_dbm(tx_dbm, victim_tx_gain_dbi, relay_rx_gain_dbi,
        frequency_hz, incoming_distance_m, incoming_loss_db)
    outgoing_transfer = direct_input_dbm(0, relay_tx_gain_dbi,
        victim_rx_gain_dbi, frequency_hz, outgoing_distance_m, outgoing_loss_db)
    required = boundary - incoming - outgoing_transfer
    output_gain_cap = output_cap - incoming
    available = min(device_cap, isolation_cap, output_gain_cap)
    return dict(relay_input_dbm=incoming, outgoing_transfer_db=outgoing_transfer,
        required_gain_db=required, required_output_dbm=boundary-outgoing_transfer,
        gain_cap_device_db=device_cap, gain_cap_isolation_db=isolation_cap,
        gain_cap_output_db=output_gain_cap, available_gain_db=available,
        headroom_max_db=available-required,
        minimum_isolation_to_cross_db=required+margin,
        interpretation='conditional_catalog_and_free_space_budget_not_observed_attack')
