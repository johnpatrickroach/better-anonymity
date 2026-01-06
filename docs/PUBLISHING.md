# Publishing to PyPI

This guide outlines the steps to build and publish `better-anonymity` to PyPI.

## Prerequisites

Ensure you have the necessary build tools installed:

```bash
pip install build twine
```

You will also need an account on [PyPI](https://pypi.org/) and an API Token.

## Creating an API Token

1.  Log in to your account on [PyPI](https://pypi.org/).
2.  Go to **Account Settings**.
3.  Scroll down to the **API tokens** section and click **Add API token**.
4.  **Description**: `better-anonymity-upload` (or similar).
5.  **Scope**: Select **Entire account** (for the first upload) or restrict to `better-anonymity` if the project already exists.
6.  Click **Add token**.
7.  **COPY THE TOKEN IMMEDIATELY**. It starts with `pypi-`. This is the only time you will see it.

## 1. Build the Package

Run the build command from the project root. This creates the distribution files in `dist/`.

```bash
python3 -m build
```

You should see output indicating that `.tar.gz` and `.whl` files have been created in the `dist/` directory.

## 2. Test the Distribution (Optional)

You can check if the package description will render correctly on PyPI:

```bash
twine check dist/*
```

## 3. Upload to PyPI

Upload the built artifacts using Twine:

```bash
twine upload dist/*
```

You will be prompted for your username (use `__token__`) and your password (your PyPI API token).

## 4. Automation (GitHub Actions)

For automated publishing, consider adding a GitHub workflow that runs on release creation.

### Example `.github/workflows/pypi.yml`

```yaml
name: Publish to PyPI
on:
  release:
    types: [created]

jobs:
  pypi:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Set up Python
        uses: actions/setup-python@v2
        with:
          python-version: '3.x'
      - name: Install build dependencies
        run: pip install build twine
      - name: Build package
        run: python -m build
      - name: Publish to PyPI
        env:
          TWINE_USERNAME: __token__
          TWINE_PASSWORD: ${{ secrets.PYPI_API_TOKEN }}
        run: twine upload dist/*

## 5. Configuring GitHub Secrets

To make the automated publishing work, you need to provide your PyPI API token to GitHub safely:

1.  Go to your GitHub Repository.
2.  Click on **Settings** (top right tab).
3.  In the left sidebar, click **Secrets and variables**, then select **Actions**.
4.  Click the green **New repository secret** button.
5.  **Name**: `PYPI_API_TOKEN`
6.  **Secret**: Paste your API token from PyPI (it starts with `pypi-`).
7.  Click **Add secret**.

Once this is set, the "Publish to PyPI" workflow will automatically authenticate using this token whenever you create a new Release.
```
