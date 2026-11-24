# Releasing

1. Set `version` in `plugins/flash/Cargo.toml`, run `cargo build --manifest-path plugins/flash/Cargo.toml`
   to refresh `plugins/flash/Cargo.lock`, and commit both. The version of the release is the version of the
   `flash` crate, because it is the only part that is built.
2. Tag and push: `git tag vX.Y.Z && git push origin main vX.Y.Z`. The `Release` workflow tests, builds one
   archive per Mac architecture and creates the GitHub release. Each archive holds `tyrannosaur.lua`,
   `lib.lua` and `plugins/` with the `flash` binary in `plugins/flash/bin/`.
3. Update the formula in [`g4rcez/homebrew-tap`](https://github.com/g4rcez/homebrew-tap). The checksums are in
   the `SHA256SUMS` file of the release:

   ```sh
   curl -sL https://github.com/g4rcez/tyrannosaur/releases/download/vX.Y.Z/SHA256SUMS
   ```

## Formula

`Formula/tyrannosaur.rb`. The archive has one top-level folder, which Homebrew strips, so `prefix.install`
copies the files as they are.

```ruby
class Tyrannosaur < Formula
  desc "Rex terminal plugins in one package: flash hints, pane numbers and scroll mode"
  homepage "https://github.com/g4rcez/tyrannosaur"
  version "X.Y.Z"
  license "MIT"

  depends_on :macos
  depends_on "jq" # plugins/panes/bin/panes uses it

  on_arm do
    url "https://github.com/g4rcez/tyrannosaur/releases/download/vX.Y.Z/tyrannosaur-vX.Y.Z-aarch64-apple-darwin.tar.gz"
    sha256 "<aarch64 checksum>"
  end

  on_intel do
    url "https://github.com/g4rcez/tyrannosaur/releases/download/vX.Y.Z/tyrannosaur-vX.Y.Z-x86_64-apple-darwin.tar.gz"
    sha256 "<x86_64 checksum>"
  end

  def install
    (share/"tyrannosaur").install "tyrannosaur.lua", "lib.lua", "plugins"
  end

  def caveats
    <<~EOS
      Add this to your Rex init.lua. A plugin that is not in the table is disabled:

        dofile("#{opt_share}/tyrannosaur/tyrannosaur.lua") {
          flash = { hints = "ctrl+p>y", flash = "ctrl+p>/" },
          panes = { keys = "ctrl+p>q" },
        }
    EOS
  end
end
```

## Move from the old formulas

`rexflash` and `rexpanes` define the actions `rexflash_hint`, `rexflash_flash` and `pane_select`. The
tyrannosaur actions are `flash_hint`, `flash_search` and `panes_select`. After the first release, set
`deprecate!` in both old formulas and tell users to change their `init.lua` to the single call above.
