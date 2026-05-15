# Rheo packages

A collection of [Rheo](https://rheo.ohrg.org) packages.

## Installation

Clone this repo into your Typst package cache:

```sh
git clone git@github.com:freecomputinglab/rheo-packages.git "$(typst info --format json | jq -r '.package-cache-path')/rheo"
```

Run `typst info` to see your package cache path.

## Usage

Once you have cloned the repo as per above, you can import these packages through the `@rheo` namespace in any Typst file.

```typ
#import "@rheo/slides:0.1.0": slides
```
