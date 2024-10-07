#!/bin/bash

# 다운로드 URL (64비트로 변경)
IMG_URL="https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2024-03-15/2024-03-15-raspios-bookworm-arm64-lite.img.xz"

# 다운로드할 파일명
IMG_XZ="raspios-bookworm-armhf-lite.img.xz"
IMG="raspios-bookworm-armhf-lite.img"

# nvme0n1 디스크 경로
DISK="/dev/nvme0n1"

# 이미지 파일 확인
if [ -f "$IMG" ]; then
  echo "이미지 파일이 이미 존재합니다. 다운로드 및 압축 해제 단계를 건너뜁니다."
else
  echo "1. 이미지 다운로드 중..."
  wget -O $IMG_XZ "$IMG_URL"
  if [ $? -ne 0 ]; then
    echo "이미지 다운로드 실패"
    exit 1
  fi
  echo "이미지 다운로드 완료: $IMG_XZ"

  echo "2. 이미지 압축 해제 중..."
  unxz $IMG_XZ
  if [ $? -ne 0 ]; then
    echo "이미지 압축 해제 실패"
    exit 1
  fi
  echo "이미지 압축 해제 완료: $IMG"
fi

# NVMe 디스크 포맷
echo "3. NVMe 디스크 포맷 중..."
sudo wipefs -a $DISK
sudo mkfs.ext4 $DISK
if [ $? -ne 0 ]; then
  echo "NVMe 디스크 포맷 실패: $DISK"
  exit 1
fi
echo "NVMe 디스크 포맷 완료: $DISK"

# 이미지 디스크에 복사
echo "4. 이미지 디스크에 복사 중..."
sudo dd if=$IMG of=$DISK bs=4M status=progress conv=fsync
if [ $? -ne 0 ]; then
  echo "이미지 디스크에 복사 실패: $DISK"
  exit 1
fi
echo "이미지 디스크에 복사 완료: $DISK"

# 부팅 파티션 마운트
BOOT_PARTITION="/mnt/boot"
echo "5. 부팅 파티션 마운트 중..."
sudo mkdir -p $BOOT_PARTITION
sudo mount ${DISK}p1 $BOOT_PARTITION
if [ $? -ne 0 ]; then
  echo "부팅 파티션 마운트 실패: $BOOT_PARTITION"
  exit 1
fi
echo "부팅 파티션 마운트 완료: $BOOT_PARTITION"

# SSH 활성화
echo "6. SSH 활성화 중..."
sudo touch $BOOT_PARTITION/ssh
if [ $? -ne 0 ]; then
  echo "SSH 활성화 실패"
  exit 1
fi
echo "SSH 활성화 완료"

# 사용자 계정 설정
echo "7. 사용자 계정 설정 중..."
USER="pi"
PASSWORD="raspberry"
HASHED_PASSWORD=$(echo $PASSWORD | openssl passwd -6 -stdin)
echo "$USER:$HASHED_PASSWORD" | sudo tee $BOOT_PARTITION/userconf.txt
if [ $? -ne 0 ]; then
  echo "사용자 계정 설정 실패"
  exit 1
fi
echo "사용자 계정 설정 완료"

# 커널 옵션 추가
KERNEL_OPTIONS="nvme_core.default_ps_max_latency_us=0 pcie_aspm=off"
echo "8. 커널 옵션 추가 중..."
sudo sed -i "s/$/ ${KERNEL_OPTIONS}/" $BOOT_PARTITION/cmdline.txt
if [ $? -ne 0 ]; then
  echo "커널 옵션 추가 실패"
  exit 1
fi
echo "커널 옵션 추가 완료"

# 부팅 파티션 언마운트
echo "9. 부팅 파티션 언마운트 중..."
sudo umount $BOOT_PARTITION
if [ $? -ne 0 ]; then
  echo "부팅 파티션 언마운트 실패"
  exit 1
fi
echo "부팅 파티션 언마운트 완료"

# 루트 파티션 마운트
ROOT_PARTITION="/mnt/root"
echo "10. 루트 파티션 마운트 중..."
sudo mkdir -p $ROOT_PARTITION
sudo mount ${DISK}p2 $ROOT_PARTITION
if [ $? -ne 0 ]; then
  echo "루트 파티션 마운트 실패: $ROOT_PARTITION"
  exit 1
fi
echo "루트 파티션 마운트 완료: $ROOT_PARTITION"

# 초기 계정 sudoer 설정
echo "11. 초기 계정 sudoer 설정 중..."
sudo cp $ROOT_PARTITION/etc/sudoers $ROOT_PARTITION/etc/sudoers.bak
echo "pi ALL=(ALL) NOPASSWD: ALL" | sudo tee -a $ROOT_PARTITION/etc/sudoers.d/010_pi-nopasswd
if [ $? -ne 0 ]; then
  echo "초기 계정 sudoer 설정 실패"
  exit 1
fi
echo "초기 계정 sudoer 설정 완료"

# 루트 파티션 언마운트
echo "12. 루트 파티션 언마운트 중..."
sudo umount $ROOT_PARTITION
if [ $? -ne 0 ]; then
  echo "루트 파티션 언마운트 실패"
  exit 1
fi
echo "루트 파티션 언마운트 완료"

echo "작업 완료: Raspberry Pi OS 이미지 복사 및 설정 완료."
