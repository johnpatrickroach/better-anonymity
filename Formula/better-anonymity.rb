class BetterAnonymity < Formula
  desc "MacOS Security, Privacy & Anonymity Tools"
  homepage "https://github.com/phaedrus/better-anonymity" # Placeholder
  license "MIT"
  head "https://github.com/phaedrus/better-anonymity.git", branch: "main"

  # No url/sha256 needed for local dev/head-only formula initially, 
  # or user can install via directory path.

  def install
    # Install specific directories to libexec to ensure correct structure
    # and avoid picking up build artifacts or git metadata
    libexec.install "bin", "lib", "README.md", "LICENSE"
    
    # Symlink the main binary from libexec/bin to the global bin directory
    bin.install_symlink libexec/"bin/better-anonymity"
    
    # Create aliases pointing to the SAME target in libexec
    bin.install_symlink libexec/"bin/better-anonymity" => "better-anon"
    bin.install_symlink libexec/"bin/better-anonymity" => "b-a"
  end

  def caveats
    <<~EOS
      You can now run 'better-anonymity', 'better-anon', or 'b-a'.
      
      To start using the tool, run:
        b-a
        
      To check your privacy score:
        b-a diagnose
    EOS
  end

  test do
    assert_match "Usage", shell_output("#{bin}/better-anonymity help")
  end
end
