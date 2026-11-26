class PinentryTouchid < Formula
  desc "Native macOS GnuPG pinentry with Touch ID"
  homepage "https://github.com/light4/pinentry-touchid"
  url "https://github.com/light4/pinentry-touchid/archive/refs/tags/v0.1.1.tar.gz"
  sha256 "b657e6e36e58de00969562618127cf87b978295d7cc86a8ffd747cd1be8beb12"
  head "https://github.com/light4/pinentry-touchid.git", branch: "main"

  depends_on macos: :ventura
  uses_from_macos "swift" => :build, since: :sequoia

  def install
    system "swift", "build", *std_swift_args
    bin.install ".build/release/pinentry-touchid"
  end

  def caveats
    <<~EOS
      Set pinentry-program in ~/.gnupg/gpg-agent.conf to:
        #{opt_bin}/pinentry-touchid
      Then run:
        gpg-connect-agent reloadagent /bye

      Installation does not modify GPG configuration or Keychain entries.
      Keychain caching is opt-in in the passphrase dialog.
    EOS
  end

  test do
    assert_match "pinentry-touchid (Swift) 0.1.1", shell_output("#{bin}/pinentry-touchid --version")
    assert_equal "OK pinentry-touchid Swift ready\nD swift-touchid\nOK\nOK closing connection\n",
                 pipe_output(bin/"pinentry-touchid", "GETINFO flavor\nBYE\n", 0)
  end
end
