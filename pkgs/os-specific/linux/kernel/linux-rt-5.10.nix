{
  lib,
  buildLinux,
  fetchurl,
  kernelPatches ? [ ],
  structuredExtraConfig ? { },
  extraMeta ? { },
  argsOverride ? { },
  ...
}@args:

let
  version = "5.10.237-rt131"; # updated by ./update-rt.sh
  branch = lib.versions.majorMinor version;
  kversion = builtins.elemAt (lib.splitString "-" version) 0;
in
buildLinux (
  args
  // {
    inherit version;
    pname = "linux-rt";

    # modDirVersion needs a patch number, change X.Y-rtZ to X.Y.0-rtZ.
    modDirVersion = lib.versions.pad 3 version;

    src = fetchurl {
      url = "mirror://kernel/linux/kernel/v5.x/linux-${kversion}.tar.xz";
      sha256 = "098gvqfaahabqqz64m5fwri57drwiz3006pr805sxw74w0vjgj0z";
    };

    kernelPatches =
      let
        rt-patch = {
          name = "rt";
          patch = fetchurl {
            url = "mirror://kernel/linux/kernel/projects/rt/${branch}/older/patch-${version}.patch.xz";
            sha256 = "15f4dylrwm9q0dl3jhcy57611w5kzz74rf9aqfvh7cqxi5q4g8fs";
          };
        };
      in
      [ rt-patch ] ++ kernelPatches;

    structuredExtraConfig =
      with lib.kernel;
      {
        PREEMPT_RT = yes;
        # Fix error: unused option: PREEMPT_RT.
        EXPERT = yes; # PREEMPT_RT depends on it (in kernel/Kconfig.preempt)
        # Fix error: option not set correctly: PREEMPT_VOLUNTARY (wanted 'y', got 'n').
        PREEMPT_VOLUNTARY = lib.mkForce no; # PREEMPT_RT deselects it.
        # Fix error: unused option: RT_GROUP_SCHED.
        RT_GROUP_SCHED = lib.mkForce (option no); # Removed by sched-disable-rt-group-sched-on-rt.patch.
      }
      // structuredExtraConfig;

    extraMeta = extraMeta // {
      inherit branch;
    };
  }
  // argsOverride
)
