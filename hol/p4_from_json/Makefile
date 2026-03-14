EXCLUDES := $(shell find excludes -name '*.exclude' ! -path 'excludes/static/bug/*' -printf '-e %p ')

sim-p4c-v1model:
	mkdir -p /evaluation/p4c/hol4p4/dynamic
	./run-tests.sh -o /evaluation/p4c/hol4p4/dynamic/v1model.log $(EXCLUDES) p4c-v1model/

sim-p4c-ebpf:
	mkdir -p /evaluation/p4c/hol4p4/dynamic
	./run-tests.sh -o /evaluation/p4c/hol4p4/dynamic/ebpf.log $(EXCLUDES) p4c-ebpf/

sim-p4testgen-v1model:
	mkdir -p /evaluation/p4testgen/hol4p4/dynamic
	./run-tests.sh -o /evaluation/p4testgen/hol4p4/dynamic/v1model.log -e hol4p4.exclude $(EXCLUDES) p4testgen-v1model/

sim-p4testgen-ebpf:
	mkdir -p /evaluation/p4testgen/hol4p4/dynamic
	./run-tests.sh -o /evaluation/p4testgen/hol4p4/dynamic/ebpf.log $(EXCLUDES) p4testgen-ebpf/

