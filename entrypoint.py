#! /usr/bin/env python

import argparse
import signal
import subprocess

parser = argparse.ArgumentParser(
    description="Run the Spack .gitlab-ci.yaml generation worker service")

def aa(*args, **kwargs):
    parser.add_argument(*args, required=True, **kwargs)

aa("-q", "--queue-dir" , help="Path from which to dequeue pending requests")
aa("-c", "--cache-dir" , help="Path in which to store response data")
aa("-r", "--remote"    , help="Git remote to clone from")
aa("-n", "--notify-url", help="URL prefix to POST notifications")

args = parser.parse_args()

signal.signal(signal.SIGINT, signal.SIG_IGN)
signal.signal(signal.SIGTERM, signal.SIG_IGN)

code = 2
while code == 2:
    child = subprocess.Popen(
            ["entr", "-d", "bash", "glciy-worker.bash",
                args.queue_dir, args.cache_dir, args.remote, args.notify_url],
            stdin=subprocess.PIPE)

    child.stdin.write(args.queue_dir)
    child.stdin.write("\n")
    child.stdin.flush()
    child.stdin.close()

    code = child.wait()

