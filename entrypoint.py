#! /usr/bin/env python

import argparse
import subprocess
import time

parser = argparse.ArgumentParser(
    description="Run the Spack .gitlab-ci.yaml generation worker service")

def aa(*args, **kwargs):
    parser.add_argument(*args, required=True, **kwargs)

aa("-q", "--queue-dir"    , help="Path from which to dequeue pending requests")
aa("-c", "--cache-dir"    , help="Path in which to store response data")
aa("-r", "--remote"       , help="Git remote to clone from")
aa("-n", "--notify-url"   , help="URL prefix to POST notifications")
aa("-p", "--poll-interval", help="File system poll interval", type=int)

args = parser.parse_args()

code = 0
while code == 0:
    child = subprocess.Popen([
        "bash", "glciy-worker.bash",
                args.queue_dir, args.cache_dir, args.remote, args.notify_url])
    time.sleep(args.poll_interval)
    code = child.wait()

