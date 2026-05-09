{
  description = "Standalone Ghostty cursor presets from Yazelix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      fenix,
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      mkPkgs = system: nixpkgs.legacyPackages.${system};
      yzcPackage =
        system: pkgs:
        let
          rustToolchain = fenix.packages.${system}.combine [
            fenix.packages.${system}.stable.cargo
            fenix.packages.${system}.stable.rustc
          ];
          rustPlatform = pkgs.makeRustPlatform {
            cargo = rustToolchain;
            rustc = rustToolchain;
          };
          source = pkgs.lib.cleanSourceWith {
            name = "yazelix-ghostty-cursors-source";
            src = ./.;
            filter =
              path: _type:
              let
                relativePath = pkgs.lib.removePrefix ((toString ./.) + "/") (toString path);
              in
              relativePath != "target"
              && !pkgs.lib.hasPrefix "target/" relativePath
              && relativePath != ".git"
              && !pkgs.lib.hasPrefix ".git/" relativePath;
          };
        in
        rustPlatform.buildRustPackage {
          pname = "yazelix-ghostty-cursors";
          version = "0.1.0";

          src = source;
          cargoLock.lockFile = ./Cargo.lock;
          cargoBuildFlags = [
            "--bin"
            "yzc"
          ];
          dontStrip = true;

          postInstall = ''
            set -eu

            share_dir="$out/share/yazelix/yazelix_ghostty_cursors"
            legacy_share_dir="$out/share/yazelix/ghostty_cursor_shaders"
            examples_dir="$share_dir/examples"
            work="$TMPDIR/yazelix_ghostty_cursors_export"
            config_dir="$work/config"

            mkdir -p "$share_dir" "$examples_dir" "$config_dir"
            cp -R ${./assets/ghostty/shaders} "$share_dir/shaders"

            "$out/bin/yzc" --config-dir "$config_dir" --share-dir "$share_dir" init
            "$out/bin/yzc" --config-dir "$config_dir" --share-dir "$share_dir" generate ghostty

            chmod -R u+w "$share_dir/shaders"
            rm -rf "$share_dir/shaders"
            cp -R "$config_dir/shaders" "$share_dir/shaders"

            cat > "$examples_dir/ghostty_blaze_tail.conf" <<EOF
# Yazelix cursor shader example for Ghostty
#
# Add these lines to a Ghostty config to try the blaze palette with the tail effect
custom-shader = $share_dir/shaders/cursor_trail_blaze.glsl
custom-shader = $share_dir/shaders/generated_effects/tail.glsl
EOF

            cat > "$share_dir/README.md" <<EOF
# Yazelix Ghostty Cursors

This package exports complete Ghostty cursor shader files generated from Yazelix cursor presets

The package also includes the \`yzc\` CLI for standalone cursor config:

\`\`\`bash
yzc init
yzc generate ghostty
\`\`\`

Then include the generated file from Ghostty:

\`\`\`conf
config-file = ~/.config/yazelix_ghostty_cursors/ghostty.conf
\`\`\`

Use one cursor palette shader and one optional effect shader in your Ghostty config:

\`\`\`conf
custom-shader = $share_dir/shaders/cursor_trail_blaze.glsl
custom-shader = $share_dir/shaders/generated_effects/tail.glsl
\`\`\`

Generated shader root:

\`\`\`text
$share_dir/shaders
\`\`\`

Example config:

\`\`\`text
$examples_dir/ghostty_blaze_tail.conf
\`\`\`

This package does not mutate your Ghostty config and does not include Yazelix runtime reroll behavior
EOF

            ln -s "$share_dir" "$legacy_share_dir"

            required_files="
              $share_dir/shaders/cursor_trail_blaze.glsl
              $share_dir/shaders/cursor_trail_snow.glsl
              $share_dir/shaders/cursor_trail_neon.glsl
              $share_dir/shaders/cursor_trail_magma.glsl
              $share_dir/shaders/generated_effects/tail.glsl
              $share_dir/shaders/generated_effects/ripple.glsl
              $examples_dir/ghostty_blaze_tail.conf
              $out/bin/yzc
            "
            for required in $required_files; do
              test -s "$required"
            done
            grep -q "custom-shader = $share_dir/shaders/cursor_trail_blaze.glsl" "$examples_dir/ghostty_blaze_tail.conf"
          '';

          meta = {
            description = "Standalone Ghostty cursor presets from Yazelix";
            homepage = "https://github.com/luccahuguet/yazelix-ghostty-cursors";
            license = pkgs.lib.licenses.asl20;
            mainProgram = "yzc";
          };
        };
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = mkPkgs system;
          yzc = yzcPackage system pkgs;
        in
        {
          default = yzc;
          yzc = yzc;
          yazelix_ghostty_cursors = yzc;
        }
      );

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.yzc}/bin/yzc";
        };
        yzc = {
          type = "app";
          program = "${self.packages.${system}.yzc}/bin/yzc";
        };
        yazelix_ghostty_cursors = {
          type = "app";
          program = "${self.packages.${system}.yzc}/bin/yzc";
        };
      });

      checks = forAllSystems (system: {
        yzc = self.packages.${system}.yzc;
      });
    };
}
