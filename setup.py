from setuptools import setup
import glob

with open("README.md", "r", encoding="utf-8") as fh:
    long_description = fh.read()

setup(
    name="better-anonymity",
    version="1.0.0",
    author="John Patrick Roach",
    description="A macOS CLI for advanced privacy, security hardening, and anonymity.",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/johnpatrickroach/better-anonymity",
    
    # Places the CLI natively into the user's bin/ PATH
    scripts=['bin/better-anonymity'],
    
    # Packages the bash libraries into a namespace folder so we don't pollute global /usr/local/lib
    data_files=[
        ('lib/better-anonymity', glob.glob('lib/*')),
        ('config/better-anonymity', glob.glob('config/*')),
    ],
    
    classifiers=[
        "Programming Language :: Unix Shell",
        "Operating System :: MacOS",
    ],
    python_requires=">=3.6",
)
