# Password Generator Documentation

## Overview
The Password Generator module helps you create strong, memorable passphrases based on the [Diceware] method recommended by the Electronic Frontier Foundation (EFF).

## Features
- **Diceware Generation**: Generates passphrases by selecting random words from an EFF-recommended wordlist.
- **Strength Analysis**: Analyzes your password or passphrase and provides a strength rating (Weak, Moderate, Strong, Excellent) based on length and complexity.

## Usage

### CLI
You can generate a password directly from the command line:

```bash
# Generate a standard 6-word passphrase (default)
./bin/better-anonymity generate-password

# Generate a custom length passphrase (e.g., 8 words)
./bin/better-anonymity generate-password 8
```

The tool will output the generated password and a strength analysis:
```text
Generated Password: correct horse battery staple
Password Strength Analysis:
Length: 28 characters
Rating: Strong
Tip: Use effective diceware passphrases (4+ random words) for high security and memorability.
```

### Interactive Menu
1. Run `./bin/better-anonymity`
2. Select Option **6. Generate Strong Password**

## Why Diceware?
Traditional passwords like `Tr0ub4dor&3` are hard for humans to remember but easy for computers to guess. A Diceware passphrase like `correct horse battery staple` is easy to remember but has much higher entropy (randomness), making it extremely difficult for computers to crack.

[Diceware]: https://www.eff.org/dice
