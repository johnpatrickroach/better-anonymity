from setuptools import setup, find_packages

setup(
    name="better-anonymity",
    version="1.0.0",
    description="MacOS Security, Privacy & Anonymity Tools",
    long_description=open("README.md").read(),
    long_description_content_type="text/markdown",
    author="Phaedrus",
    author_email="phaedrus@example.com",
    url="https://github.com/phaedrus/better-anonymity",
    packages=find_packages(),
    # Include the symlinked bin and lib directories as package data
    package_data={
        "better_anonymity": ["bin/*", "lib/*"]
    },
    include_package_data=True,
    entry_points={
        "console_scripts": [
            "better-anonymity=better_anonymity.__main__:main",
            "better-anon=better_anonymity.__main__:main",
            "b-a=better_anonymity.__main__:main",
        ],
    },
    classifiers=[
        "Programming Language :: Python :: 3",
        "Operating System :: MacOS",
        "License :: OSI Approved :: MIT License",
    ],
    python_requires='>=3.6',
)
