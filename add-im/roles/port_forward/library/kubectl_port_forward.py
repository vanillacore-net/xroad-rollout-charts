#!/usr/bin/python3
"""
Ansible module for managing kubectl port-forward
"""

from ansible.module_utils.basic import AnsibleModule
import subprocess
import time
import os
import signal
import json


def main():
    module = AnsibleModule(
        argument_spec=dict(
            namespace=dict(type='str', required=True),
            pod=dict(type='str', required=True),
            local_port=dict(type='int', required=True),
            remote_port=dict(type='int', required=True),
            state=dict(type='str', default='started', choices=['started', 'stopped']),
            timeout=dict(type='int', default=300),
            pid_file=dict(type='str', required=True),
        ),
        supports_check_mode=True
    )

    namespace = module.params['namespace']
    pod = module.params['pod']
    local_port = module.params['local_port']
    remote_port = module.params['remote_port']
    state = module.params['state']
    timeout = module.params['timeout']
    pid_file = module.params['pid_file']

    result = dict(
        changed=False,
        pid=None,
        local_port=local_port,
        remote_port=remote_port
    )

    if state == 'started':
        # Check if port-forward is already running
        if os.path.exists(pid_file):
            try:
                with open(pid_file, 'r') as f:
                    old_pid = int(f.read().strip())
                # Check if process is still running
                try:
                    os.kill(old_pid, 0)
                    # Process exists, port-forward is already running
                    result['pid'] = old_pid
                    module.exit_json(**result)
                except OSError:
                    # Process doesn't exist, remove stale pid file
                    os.remove(pid_file)

            except (ValueError, IOError):
                # Invalid pid file, remove it
                if os.path.exists(pid_file):
                    os.remove(pid_file)

        if not module.check_mode:
            # Start port-forward
            cmd = [
                'kubectl', 'port-forward',
                '-n', namespace,
                pod,
                f'{local_port}:{remote_port}'
            ]

            # Redirect stdout/stderr to DEVNULL to prevent buffer blocking
            # Port-forward is a long-running process that doesn't need output captured
            process = subprocess.Popen(
                cmd,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,  # Redirect stderr to prevent buffer blocking
                preexec_fn=os.setsid
            )

            # Wait a moment for port-forward to start
            time.sleep(2)

            # Check if process is still running
            if process.poll() is None:
                # Save PID
                with open(pid_file, 'w') as f:
                    f.write(str(process.pid))
                result['pid'] = process.pid
                result['changed'] = True
            else:
                # Process died immediately
                module.fail_json(
                    msg="Port-forward process died immediately after starting. Check kubectl access and pod status."
                )

    elif state == 'stopped':
        if os.path.exists(pid_file):
            try:
                with open(pid_file, 'r') as f:
                    pid = int(f.read().strip())
                # Kill the process group
                try:
                    os.killpg(os.getpgid(pid), signal.SIGTERM)
                    time.sleep(1)
                    # Force kill if still running
                    try:
                        os.killpg(os.getpgid(pid), signal.SIGKILL)
                    except ProcessLookupError:
                        pass
                    result['changed'] = True
                except ProcessLookupError:
                    # Process already dead
                    pass
                os.remove(pid_file)
            except (ValueError, IOError, ProcessLookupError):
                if os.path.exists(pid_file):
                    os.remove(pid_file)

    module.exit_json(**result)


if __name__ == '__main__':
    main()

