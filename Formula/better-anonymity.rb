class BetterAnonymity < Formula
  desc "MacOS Security, Privacy & Anonymity Tools"
  homepage "https://github.com/phaedrus/better-anonymity" # Placeholder
  license "MIT"
  head "https://github.com/phaedrus/better-anonymity.git", branch: "main"

  # No url/sha256 needed for local dev/head-only formula initially, 
  # or user can install via directory path.

  def install
    # Install everything to the prefix (e.g. /usr/local/Cellar/better-anonymity/HEAD)
    prefix.install Dir["*"]
    
    # Homebrew automatically links bin/* to /usr/local/bin
    
    # Create aliases
    # We use bin.install_symlink pointing to the name of the executable *in bin*
    bin.install_symlink "better-anonymity" => "better-anon"
    bin.install_symlink "better-anonymity" => "b-a"
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
