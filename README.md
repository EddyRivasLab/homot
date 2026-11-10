# Homot: Homology Observation Tool

Homot is a GUI tool for the exploration of homology search results.  Users can display search results on a taxonomic tree, grouped by structure (sets of annotated regions such as Pfam domains), or sorted by e-value.  Homot can read search results from HMMER (in domtblout form), BLAST (in tabular form), or any search tool that can generate results in one of those two formats.

## Installation

We provide Windows (x86), macOS (ARM/M-series), and Linux (x86) operating systems on at eddylab.org/software/homot, as well as an example data set.  Downloading and running one of those installers is the easiest way to get a copy of Homot.

Building Homot from source code requires a number of tools and packages.  The process is described in our Userguide, which can be obtained by cloning this Git repository, entering the userguide directory, and running pdflatex on the file "homot_userguide.tex".

## Usage

To use Homot, you will need a FASTA file of protein sequences and an "annotations database" that contains taxonomic and structure information about those sequences.  We provide annotations databases for a few commonly-used sequence sets at eddylab.org/software/homot.  Once you have those, run one or more homology searches against the FASTA file and start Homot.  You will be presented with a screen that asks you to specify the location of the search results file(s) and annotations database to be displayed.  Doing that and clicking the "load data" button will take you to the taxonomic display of your results.

Our Userguide provides more information about how to use Homot and how to create annotations databases.

## Contents

This repository contains three directories:
1. create-annotations: Programs for creating annotations databases from FASTA files.
2. homot: The source code for Homot
3. userguide: Our user guide
