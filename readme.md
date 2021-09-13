## IMSI Pseudo

### About

This project designs a specification and provides a
reference implementation of a mechanism to conceal the IMSI
(international mobile subscriber identity) of a mobile
subscriber on the radio interface

### Components

- `shadysim`: a Python2 program to work with Toorcamp SIM
  cards
- converter: a Java binary to convert between CAP, JCA and
  EXP formats
- a `makefile` with phony targets: this seems to be the
  heart of the project. It makes use of above binaries to
  perform "pseudonymization" and IMSI concealing.

### Usage

This flake provides the following:

**Packages**

 - `shadysim-bin`
 - `converter-bin`

These can be built as standalone packages via:

```
nix build github:ngi-nix/imsi-pseudo#shadysim-bin
nix build github:ngi-nix/imsi-pseudo#converter-bin
```

However, ideally you want to make use of the following flake
apps.

**Apps**

 - `flash`: flash given KIC1 and KID1 into the SIM
 - `list`: an alias for `shadysim-bin --list-applets`
 - `reflash`: an alias for `remove` followed `flash`
 - `remove`: safely remove the sim-applet

```
# create a file called .sim-keys
cat << EOF > .sim-keys
KIC1="FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"
KID1="FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"
EOF

# run flash/remove/list/reflash
nix run github:ngi-nix/imsi-pseudo#flash
```
