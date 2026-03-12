#!/bin/bash

sudo apt-get install -y opam
opam init --auto-setup --yes --disable-sandboxing
opam switch create hol4p4 4.13.1
eval $(opam env --switch=hol4p4)
