#### Change these settings to modify how this ISO is built.
#  The directory that you'll be using for the actual build process.
SHELL = /bin/sh
WORKDIR=archbangftw
#  Yüklenecek paketlerin listesi, bir dizede ayrılmış alan veya bir dosyada ayrılmış satır. Grupları içerebilir.
PACKAGES="$(shell cat packages.list packages.list.aur) syslinux"
# ISO dosyamızın adı. Mimariyi belirtmiyor!
NAME=aylinux
# ISO sürümü eklenecektir.
VER=2021
# Çekirdek sürümü. Buna ihtiyacın olacak.
KVER=2.6.34-ARCH
# ISO adına mimari de eklenecektir. 
ARCH?=$(shell uname -m)
# Mevcut çalışma dizini 
PWD:=$(shell pwd)
# Bu son iso/img'nin taşıyacağı tam isim olacak 
FULLNAME="$(PWD)"/$(NAME)-$(VER)-$(ARCH)
# Varsayılan olarak, her şeyi oluşturmak için talimatlar oluşturun.
all: archbang

rem:
	$(SHELL) "$(PWD)"/scripts/fetch-pkg.sh
	
#Aşağıdakiler ilk olarak son iso görüntüsünü oluşturmadan önce temel-fs rutinini çalıştıracaktır. 
archbang: rem base-fs 
	touch "$(FULLNAME)".iso
	rm -r "$(FULLNAME)".iso
	mkarchiso -v -p syslinux iso "$(WORKDIR)" "$(FULLNAME)".iso

# Bu, çalışan dosya sistemini yapmanın ana kuralıdır. Rutinleri soldan sağa doğru çalıştıracaktır. 
# Böylelikle önce kök imajı ve son olarak syslinux adı verilir. 
base-fs: root-image boot-files initcpio overlay iso-mounts syslinux

# Kök görüntü rutini her zaman önce yürütülür.  
# Yalnızca tüm paketleri $WORKDIR'e indirip kurarak size temel olarak kullanabileceğiniz temel bir sistem sağlar. 
root-image: "$(WORKDIR)"/root-image/.arch-chroot
"$(WORKDIR)"/root-image/.arch-chroot:
root-image:
	mkarchiso -v -p $(PACKAGES) create "$(WORKDIR)"

# Rule for make /boot
boot-files: 
	cp -r "$(WORKDIR)"/root-image/boot "$(WORKDIR)"/iso/
	cp -r boot-files/* "$(WORKDIR)"/iso/boot/

# initcpio görüntüleri için kurallar 
initcpio: "$(WORKDIR)"/iso/boot/archbang.img
"$(WORKDIR)"/iso/boot/archbang.img: mkinitcpio.conf "$(WORKDIR)"/root-image/.arch-chroot
	mkdir -p "$(WORKDIR)"/iso/boot
	mkinitcpio -c ./mkinitcpio.conf -b "$(WORKDIR)"/root-image -k $(KVER) -g $@

# See: Overlay
overlay:
	mkdir -p "$(WORKDIR)"/overlay/etc/pacman.d
	cp -r overlay "$(WORKDIR)"/
	chmod 0440 "$(WORKDIR)"/overlay/etc/sudoers
	wget -O "$(WORKDIR)"/overlay/etc/pacman.d/mirrorlist http://www.archlinux.org/mirrorlist/$(ARCH)/all/
	sed -i "s/#Server/Server/g" "$(WORKDIR)"/overlay/etc/pacman.d/mirrorlist	
#	chmod 0440 "$(WORKDIR)"/root-image/etc/sudoers
# İsomounts dosyasını işleme kuralı. 
iso-mounts: "$(WORKDIR)"/isomounts
"$(WORKDIR)"/isomounts: isomounts root-image
	sed "s|@ARCH@|$(ARCH)|g" isomounts > $@

# Bu rutin her zaman gerçek görüntüyü oluşturmadan hemen önce yürütülür. 
syslinux:
	mkdir -p $(WORKDIR)/iso/boot/isolinux
	cp $(WORKDIR)/root-image/usr/lib/syslinux/*.c32 $(WORKDIR)/iso/boot/isolinux/
	cp $(WORKDIR)/root-image/usr/lib/syslinux/isolinux.bin $(WORKDIR)/iso/boot/isolinux/	
# "Make clean" çağrılması durumunda, aşağıdaki rutin bu Makefile tarafından oluşturulan tüm dosyalardan kurtulacaktır. 
clean:
	rm -rf "$(WORKDIR)" "$(FULLNAME)".img "$(FULLNAME)".iso

refresh: overlay boot-files syslinux	
	touch "$(FULLNAME)".iso	
	rm "$(FULLNAME)".iso
	mkarchiso -v -p syslinux iso "$(WORKDIR)" "$(FULLNAME)".iso

.PHONY: all archbang
.PHONY: base-fs
.PHONY: root-image boot-files initcpio overlay iso-mounts
.PHONY: syslinux
.PHONY: clean
.PHONY: refresh
