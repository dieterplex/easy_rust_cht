#!/usr/bin/env bash

# Execute this script to generate a mdBook version from the single Readme.md file present in this repository.
# Usage: ./createBookFromReadme.sh

# Availble options:
# - book (default)
# - gh-pages
# - pdf
ARTIFACT=$1
CSPLIT=

# -------------------- Utility Methods --------------------
# Check for binaries
function checkEnvironment(){
    if [[ $OSTYPE == darwin* ]]; then
        type $CSPLIT >/dev/null 2>&1 || { echo "Install 'gcsplit' first (e.g. via 'brew install coreutils')." >&2 && exit 1 ; }
        CSPLIT=gcsplit;
    elif [[ $OSTYPE == linux* ]]; then
        type $CSPLIT >/dev/null 2>&1 || { echo "Install 'csplit' first (with 'coreutils' via your distro package manager)." >&2 && exit 1 ; }
        CSPLIT=csplit;
    else
        echo "Unsupported platformt" && exit 1;
    fi
}

function checkEnvironmentMdBook(){
    type mdbook >/dev/null 2>&1 || { echo "Install 'mdbook' first (e.g. via 'cargo install mdbook')." >&2 && exit 1 ; }
}

# Check for binaries generating PDF
function checkEnvironmentPdf(){
    type pandoc >/dev/null 2>&1 || { echo "Install 'pandoc' first (e.g. via 'brew install pandoc' or 'apt-get install pandoc')." >&2 && exit 1 ; }
    type xelatex >/dev/null 2>&1 || { echo "Install 'xelatex' first" >&2 && exit 1 ; }
}

# Splits the Readme.md file based on the header in markdown and creates chapters
# Note:
#   Get gcsplit via homebrew on mac: brew install coreutils
function splitIntoChapters(){
    pushd src > /dev/null
    $CSPLIT --prefix='Chapter_' --suffix-format='%d.md' --elide-empty-files ../README.md '/^## /' '{*}' -q
    popd > /dev/null
}

# Creates the summary from the generated chapters
function createSummary(){
    pushd src > /dev/null
    touch SUMMARY.md
    echo '# Summary' > SUMMARY.md
    echo "" >> SUMMARY.md
    for f in $(ls -tr | grep Chapter_ | sort -V); do
        # Get the first line of the file
        local firstLine=$(sed -n '1p' $f)
        local cleanTitle=$(echo $firstLine | cut -c 3-)
        echo "- [$cleanTitle](./$f)" >> SUMMARY.md;
    done
    popd > /dev/null
}

# Copy Easy_Rust_sample_image.png in the current folder in order to be found.
function copyAssets(){
    cp *.png src
}

# Builds the mdBook version from src directory and starts serving locally.
# Note:
#     Install mdBook as per instructions in their repo https://github.com/rust-lang/mdBook
function buildAndServeBookLocally(){
    mdbook build && mdbook serve --open
}

# Creates the summary from the generated chapters
function convertToLatex(){
    pushd latex > /dev/null

    # Step 1: run pandoc on README.md which generates the `.tex` file.

    # Commands used previously (didn't require metadata.yaml). Left here for reference...
    # pandoc ../README.md -V geometry:margin=0.7in -V colorlinks=true -V linkcolor=blue -V urlcolor=blue -V toccolor=gray --standalone --from markdown --to latex > easy_rust.tex
    # pandoc ../README.md --standalone --from markdown --to latex > easy_rust.tex

    # generates `easy_rust.tex` in the current folder using the instructions given inside `../pdf_metadata.yaml`.
    pandoc ../README.md ../pdf_metadata.yaml -s -o easy_rust.tex # --toc    # The `toc` flag can be added or not depending on personal preferences.
    # If added, the `xelatex` command right below needs to be run twice (the first time.)
    echo "Generated easy_rust.tex file."


    # Step 2: run `xelatex` on the `.tex` file to geneate the PDF.
    xelatex --interaction=nonstopmode easy_rust.tex
    # to generate the TOC you need to run this twice
    # xelatex --interaction=nonstopmode easy_rust.tex
    
    echo "Generated PDF file easy_rust.pdf"
    popd > /dev/null
}

# -------------------- Steps to create different artifact --------------------
function build(){
    case $ARTIFACT in
        book)
            # Steps to create the mdBook version
            checkEnvironment
            checkEnvironmentMdBook
            splitIntoChapters
            createSummary
            copyAssets
            buildAndServeBookLocally
        ;;
        gh-pages)
            # Steps to create content of github pages
            checkEnvironment
            splitIntoChapters
            createSummary
            copyAssets
        ;;
        pdf)
            # Steps to create PDF version
            checkEnvironmentPdf
            convertToLatex
        ;;
        *)
            echo "unknown build target: $ARTIFACT"
        ;;
    esac
}

build ${ARTIFACT:=book}
