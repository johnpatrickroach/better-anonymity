import shutil
import os
from setuptools import setup
from setuptools.command.build_py import build_py

class CustomBuildPy(build_py):
    def run(self):
        super().run()
        pkg_dir = os.path.join(self.build_lib, 'better_anonymity')
        for d in ['bin', 'lib', 'config']:
            dest = os.path.join(pkg_dir, d)
            if os.path.exists(d):
                shutil.copytree(d, dest, dirs_exist_ok=True)

setup(cmdclass={'build_py': CustomBuildPy})
