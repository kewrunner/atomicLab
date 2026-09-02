# Test fixtures

The validation playbook uses `/tmp` only as a disposable local fixture. Add
invalid-input cases here when exercising preflight: empty variables, a wrong
inventory hostname, relative paths, protected roots, missing paths, files
instead of directories, and unsupported OS facts.
