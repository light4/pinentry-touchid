class PinentryTouchid < Formula
  desc "Native macOS GnuPG pinentry with Touch ID"
  homepage "https://github.com/light4/pinentry-touchid"
  url "https://github.com/light4/pinentry-touchid/archive/27abc8fc6817a2549f008eec0d3cfd351e9c6355.tar.gz"
  version "0.1.0"
  sha256 "f40b22ad8f5cb7bd001ee62e791282c436dbf5e1180f02f8899d026d6d3008ba"
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
    assert_match "pinentry-touchid (Swift) 0.1.0", shell_output("#{bin}/pinentry-touchid --version")
    assert_equal "OK pinentry-touchid Swift ready\nD swift-touchid\nOK\nOK closing connection\n",
                 pipe_output(bin/"pinentry-touchid", "GETINFO flavor\nBYE\n", 0)
  end
end
