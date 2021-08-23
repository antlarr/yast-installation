#! /usr/bin/env rspec

require_relative "./test_helper"
require "installation/unmounter"

PROC_MOUNTS_PATH = File.join(File.expand_path(File.dirname(__FILE__)), "data/proc-mounts")
PREFIX = "/mnt".freeze

def stored_proc_mounts(scenario)
  File.join(PROC_MOUNTS_PATH, "proc-mounts-#{scenario}-raw.txt")
end

describe Installation::Unmounter do
  let(:proc_mounts) { "" }

  describe "#new" do
    let(:subject) { described_class.new(PREFIX, proc_mounts) }

    context "empty" do
      it "does not crash and burn" do
        expect(subject.mounts).to eq []
      end
    end

    context "before the installation is executed" do
      let(:proc_mounts) { stored_proc_mounts("inst") }

      it "does not find any relevant mounts" do
        expect(subject.mounts).to eq []
      end
    end

    context "when reading the actual /proc/mounts file" do
      let(:proc_mounts) { nil } # use built-in default /proc/mounts

      it "ignores /, /proc, /sys, /dev" do
        expect(subject.ignored_paths).to include("/", "/proc", "/sys", "/dev")
      end

      # Don't check in this context that there is nothing to unmount:
      # The machine that executes the test might actually have something mounted at /mnt.
    end
  end

  describe "#add_mount and #clear" do
    before(:all) do
      # Start with a completely empty unmounter
      # and keep it alive between the tests of this group
      @unmounter = described_class.new(PREFIX, "")
    end

    it "starts completely empty" do
      expect(@unmounter.mounts).to eq []
      expect(@unmounter.ignored_mounts).to eq []
      expect(@unmounter.unmount_paths).to eq []
      expect(@unmounter.ignored_paths).to eq []
    end

    it "/ is ignored" do
      @unmounter.add_mount("/dev/sdx1 / ext4 defaults 0 0")
      expect(@unmounter.mounts).to eq []
      expect(@unmounter.unmount_paths).to eq []
      expect(@unmounter.ignored_paths).to eq ["/"]
    end

    it "/home is ignored" do
      @unmounter.add_mount("/dev/sdx2 /home ext4 defaults 0 0")
      expect(@unmounter.mounts).to eq []
      expect(@unmounter.unmount_paths).to eq []
      expect(@unmounter.ignored_paths).to eq ["/", "/home"]
    end

    it "/mnt will be unmounted" do
      @unmounter.add_mount("/dev/sdy1 /mnt ext4 defaults 0 0")
      expect(@unmounter.unmount_paths).to eq ["/mnt"]
      expect(@unmounter.ignored_paths).to eq ["/", "/home"]
    end

    it "/mnt/boot will be unmounted" do
      @unmounter.add_mount("/dev/sdy2 /mnt/boot ext4 defaults 0 0")
      expect(@unmounter.unmount_paths).to eq ["/mnt/boot", "/mnt"]
      expect(@unmounter.ignored_paths).to eq ["/", "/home"]
    end

    it "/mnt/boot/usb will be unmounted" do
      @unmounter.add_mount("/dev/sdy2 /mnt/boot/usb ext4 defaults 0 0")
      expect(@unmounter.unmount_paths).to eq ["/mnt/boot/usb", "/mnt/boot", "/mnt"]
      expect(@unmounter.ignored_paths).to eq ["/", "/home"]
    end

    it "#clear clears everything" do
      @unmounter.clear
      expect(@unmounter.mounts).to eq []
      expect(@unmounter.ignored_mounts).to eq []
      expect(@unmounter.unmount_paths).to eq []
      expect(@unmounter.ignored_paths).to eq []
    end
  end

  describe "common scenarios" do
    let(:subject) { described_class.new(PREFIX, proc_mounts) }

    context "partition-based btrfs with subvolumes, no separate /home" do
      let(:proc_mounts) { stored_proc_mounts("btrfs") } # see data/proc/mounts/
      let(:expected_result) do
        %w(/mnt/run
           /mnt/sys
           /mnt/proc
           /mnt/dev
           /mnt/var
           /mnt/usr/local
           /mnt/tmp
           /mnt/srv
           /mnt/root
           /mnt/opt
           /mnt/home
           /mnt/boot/grub2/x86_64-efi
           /mnt/boot/grub2/i386-pc
           /mnt/.snapshots
           /mnt)
      end

      it "will unmount /mnt/run, /mnt/sys, /mnt/proc, /mnt/dev, all subvolumes, /mnt" do
        expect(subject.unmount_paths).to eq expected_result
      end
    end

    context "partition-based btrfs with subvolumes and separate xfs /home" do
      let(:proc_mounts) { stored_proc_mounts("btrfs-xfs-home") }
      let(:expected_result) do
        %w(/mnt/run
           /mnt/sys
           /mnt/proc
           /mnt/dev
           /mnt/var
           /mnt/usr/local
           /mnt/tmp
           /mnt/srv
           /mnt/root
           /mnt/opt
           /mnt/home
           /mnt/boot/grub2/x86_64-efi
           /mnt/boot/grub2/i386-pc
           /mnt)
      end

      it "will unmount /mnt/run, /mnt/sys, /mnt/proc, /mnt/dev, all subvolumes, /mnt/home, /mnt" do
        expect(subject.unmount_paths).to eq expected_result
      end
    end

    context "encrypted LVM with btrfs with subvolumes and separate btrfs /home" do
      let(:proc_mounts) { stored_proc_mounts("btrfs-xfs-home") }
      let(:expected_result) do
        %w(/mnt/run
           /mnt/sys
           /mnt/proc
           /mnt/dev
           /mnt/var
           /mnt/usr/local
           /mnt/tmp
           /mnt/srv
           /mnt/root
           /mnt/opt
           /mnt/home
           /mnt/boot/grub2/x86_64-efi
           /mnt/boot/grub2/i386-pc
           /mnt)
      end

      it "will unmount /mnt/run, /mnt/sys, /mnt/proc, /mnt/dev, all subvolumes, /mnt/home, /mnt" do
        expect(subject.unmount_paths).to eq expected_result
      end
    end
  end
end
