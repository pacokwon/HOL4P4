## Clone Repository
```bash
git clone https://github.com/pacokwon/hol4p4 --branch harness
```

## Build Docker Image from `Dockerfile`
```bash
docker build -t hol4p4-harness -f harness.dockerfile .
```

## Run Container and Open an Interactive Shell
```bash
# Run
docker run -dit --name hol4p4 hol4p4-harness

# Open an Interactive Shell
docker exec -it hol4p4 bash
```

## Run V1Model STF Tests
```bash
# Inside /HOL4P4/hol/p4_from_json
./run-tests.sh v1model-tests
```

## Run eBPF STF Tests
```bash
# Inside /HOL4P4/hol/p4_from_json
./run-tests.sh ebpf-tests
```
