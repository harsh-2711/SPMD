## Challenge for GSoC 2019 Project on LHCb's Future Vertex Detector Reconstruction

### Description of the LHCb detector

[lhcb_det]: LHCb.png

The LHCb detector at the Large Hadron Collider (LHC) at Cern studies
particles that are created in proton-proton collisions and fly in the
direction of the axis of the accelerator. The sub-detector that is
closest to the point where the protons collide is called the Vertex
Locator (VeLo) detector.

The LHCb detector is currently being upgraded to be able to collect
data from more collisions per second. This upgrade includes an
improved VeLo detector that consists of 26 layers of pixel sensors
arrayed perpendicular to the beam axis.

In approximately 10 years, another upgrade of the experiment is
foreseen, including a new VeLo detector called VP2. This project is
about creating an algorithm to do pattern-recognition for the future
VP2 detector.

A key feature of the future detector will be the ability to very
precisely record the time when signals are detected. This will allow
to distinguish signals from different particles based on both spatial
and time information.

### Existing Implementation

There are two exisiting implementations of pattern-recognition
algorithms, neither of which uses time information. This challenge
will work with the code for one of those implementations that can be
found in the [spmd implementation repository][spmd_repo]. The code for
this challenge is located on the GSoC_2019 branch of the repository.

### Goal of the Challenge

Because the detector is being designed, all data that is used is
simulated. When simulated data is created, the groups of signals that
originate from the same simulated particle are stored to allow
comparison with those found by a pattern recognition algorithm.

The aim of this challenge is to extend an existing implementation of a
pattern recognition algorithm with code to determine how well the
algorithm is performing in terms of:
- Its capacity to find all the groups of signals that originate from
  each of the particles that traverse the detector after a
  proton-proton collission
- The number of groups of signals that are random combinations and
  did *not* originate from a particle traversing the detector

The code that performs the comparison between the output of the
pattern recognition and the saved simulated data is called
MC-checking.

#### Existing MC-checking Code

An implementation of the MC-checking algorithm exists as part of the
[Allen][allen_repo] project. It has been extracted and put in the
*checking* subdirectory in the repository. The goal of this challenge
is to integrate this code into the `main` of [this][spmd_repo]
project.

### ISPC

The pattern recognition algorithm itself is implemented in the
[ISPC language][ispc], which is based on a limited set of C/C++ with
additional features for writing vectorized code. The ispc compiler
provides a C++-compatible function interface, which is what is called
from `main`. This challenge will work with the output of the pattern
recognition algorithm, which is handled in standard C++.

### Part 1: Building the Existing Code

Part 1 of the challenge is to build the existing code using the ispc
compiler and to run it. Please:
- Download the ispc compiler binaries from the [ispc site][ispc]
- Install them on your system and add the path to the `ispc` binary to
  your shell's search path
- Use `cmake` to configure the build
- Run your selected tool (`make` by default) to build the code
- Run the `VeloReconstruction` binary

Send us the output of `VeloReconstruction` as part the result.

### Part 2: Including  and Calling the TrackChecker

Part two of this challenge aims to automate the MC-checking by porting
code from the [Allen][allen_repo] project to this project. Because
this implementation was derived from the one that is part of the
[Allen][allen_repo] project, it is relatively straightforward to also
port the MC-checking code.

The interface to the MC-checking code are the `CheckerInvoker` and the
`prepareTracks` functions.  The `prepareTracks` function converts the
groups of hits that are the output of the pattern recognition
algorithm to a format suitable for the MC-checking code. The first
step of part 2 is to modify the `prepareTracks` function to properly
do this conversion. The part of main that prints information about the
hits can be used as inspiration for an implementation.

The second part is to call `prepareTracks` from main, properly
instantiate a `CheckerInvoker` and call its `check` method. Please
send us the output of the `VeloReconstruction` binary including the
printout produced by the MC-checking code.

### Bonus

The MC-checking implementation also contains code to make plots of
various quantities using the [ROOT][] data-analysis framework
developed at Cern. Download ROOT's binaries for your system and
install them, or use your distribution's package manager if ROOT is
available there. If properly installed, CMake should detect the
presence of ROOT.

A file `output/PrCheckerPlots.root` should then be created when the
MC-checking code is run. Send us this file. It can be viewed using
ROOT's browser `rootbrowser file.root`.

ROOT can also be used from a Jupyter notebook
as explained [in this tutorial](https://root.cern.ch/notebooks/HowTos/HowTo_ROOT-Notebooks.html).
A file can be opened and it's contents viewed using this Python code:
```python
from ROOT import TFile, TCanvas
root_file = TFile::Open("path/to/output/PrCheckerPlots.root")
root_file.ls()
VeLo_dir = root_file.Get("directory_name")
histogram = VeLo_dir.Get("some_histograms_name")
canvas = TCanvas("canvas", "canvas", 600, 400)
histogram.Draw()
```
If you end up with a notebook, please send it to us including a view
of a few of the plots.

### Brief Glossary

An *event* is the data originating from two packets of protons —
called bunches — passing through each other in the middle of the VeLo
detector. When these bunches move through each other a number of
protons in each bunch may collide and produce particles that fly
through the detector.

Simulated data is also called *Monte-Carlo or MC data* after the method
used to create it, which relies on (pseudo)random numbers.

Pattern recognition algorithms in LHCb find groups of signals that
originated from the same particle traversing the detector.

### Questions and Contact

Please address questions by mail to the mentors:

- [Roel Aaij](mailto:roel.aaij@nikhef.nl)
- [Daniel Hynds](mailto:d.hynds@nikhef.nl)
- [Gerhard Raven](mailto:graven@nikhef.nl)

[spmd_repo]: https://gitlab.cern.ch/raaij/spmd_test
[allen_repo]: https://gitlab.cern.ch/lhcb-parallelization/Allen
[ispc]: https://ispc.github.io
[ROOT]: https://root.cern.ch
