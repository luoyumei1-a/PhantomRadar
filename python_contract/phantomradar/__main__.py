import argparse
import json
from .audit import audit_file

parser = argparse.ArgumentParser(description='Offline observable-only PhantomRadar trace analysis; no device or RF control.')
parser.add_argument('input_csv')
parser.add_argument('--output', required=True)
parser.add_argument('--config')
parser.add_argument('--demo', action='store_true', help='Allow synthetic_demo inputs and mark every output DEMO_')
args = parser.parse_args()
try:
    report = audit_file(args.input_csv, args.output, args.config, args.demo)
except (ValueError, OSError) as error:
    parser.exit(2, f'PhantomRadar: {error}\n')
print(json.dumps({'label':report['label'],'frames':report['frame_count'],'trials':report['trial_count'],'output':args.output},indent=2))
