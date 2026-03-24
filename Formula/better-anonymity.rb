class BetterAnonymity < Formula
  desc "macOS CLI for advanced privacy, security hardening, and anonymity"
  homepage "https://github.com/johnpatrickroach/better-anonymity"
  
  # TODO: Replace the URL and SHA256 when you create a GitHub Release
  url "https://github.com/johnpatrickroach/better-anonymity/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"
  license "MIT"

  depends_on "curl"
  depends_on "fzf" => :optional

  def install
    # Install the bin directory into the Homebrew Cellar
    bin.install "bin/better-anonymity"
    
    # Install the lib directory alongside it in the Cellar
    # Because bin/better-anonymity resolves its location via symlinks,
    # the internal relative paths (ROOT_DIR/lib/...) will work perfectly here.
    prefix.install "lib"
    
    # Install configuration and assets
    prefix.install "config" if buildpath.join("config").exist?
    prefix.install "tests" if buildpath.join("tests").exist?
    prefix.install "VERSION" if buildpath.join("VERSION").exist?
  end

  def caveats
    <<~EOS
      Better Anonymity has been successfully installed!
      
      To start the interactive system configuration menu, run:
        better-anonymity menu

      If you want the global convenience aliases (torify, stay-connected, etc) 
      injected into your shell configuration, run:
        better-anonymity install cli
    EOS
  end

  test do
    # Verify the CLI exists and can print the version/help menu without crashing
    system "#{bin}/better-anonymity", "--version"
  end
end
