# Kata-Containers 支持 Ascend NPU 技术文档
## 裸金属服务器配置：BIOS 开启 SMMU
```sh
# 开启 SMMU
BIOS 页面 --> MISC Config --> Support Smmu
BIOS 页面 --> MISC Config --> Smmu Work Around
内核配置启动参数
内核配置文件 grub.cfg 添加参数 iommu=pt intel_iommu=on，并重启节点。
```

## 切换 Ascend 卡驱动
1. 节点加载 vfio-pci 驱动
```sh
[root@modelfoundry-funcverif-machine-001 ~]# modprobe vfio-pci   
[root@modelfoundry-funcverif-machine-001 ~]# lsmod | grep -i vfio
vfio_pci               61440  0
vfio_mdev              16384  0
mdev                   24576  1 vfio_mdev
vfio_virqfd            16384  1 vfio_pci 
vfio_iommu_type1       40960  0
vfio                   36864  3 vfio_mdev,vfio_iommu_type1,vfio_pci
```

2. 切换卡驱动为 vfio-pci
```sh
# 以 01:00.0 为例
export BDF="0000:01:00.0"
echo $BDF > /sys/bus/pci/drivers/devdrv_device_driver/unbind
echo vfio-pci > /sys/bus/pci/devices/$BDF/driver_override
echo $BDF > /sys/bus/pci/drivers_probe
```

3. 验证卡驱动类型
查看卡驱动
```sh
        Capabilities: [880 v1] Physical Layer 16.0 GT/s <?>
        Kernel driver in use: vfio-pci <-- 此处驱动已切换
        Kernel modules: drv_vascend, dbl_runenv_config, drv_devmm_host, drv_devmm_host_agent, ascend_event_sched_host, drv_devmng_host, drv_pcie_hdc_ho
st, ascend_trs_sec_eh_agent, ascend_trs_sub_stars, ascend_queue, drv_davinci_intf_host, ts_agent, ascend_trs_pm_adapt, dbl_dev_identity, dbl_algorithm,
 drv_soft_fault, ascend_soc_platform, drv_dvpp_cmdlist, drv_pcie_host, drv_pcie_vnic_host, ascend_trs_shrid, drv_dp_proc_mng_host, ascend_xsmem, drv_vi
rtmng_host
```

4. 查看设备 ID
```
# ls -lsh /dev/vfio/
total 0
0 crw------- 1 root root 241,   0 Feb  2 11:08 64
0 crw-rw-rw- 1 root root  10, 196 Feb  2 10:56 vfio
```
**注意**：节点重启后，需要重新 modprobe vfio_pci，或者添加模块到 /etc/modules。

# kata-conatiners 部署

## 部署 kata-containers
此文档使用版本为 kata-containers v3.2.0
参考文档：https://github.com/kata-containers/kata-containers/tree/main/docs/install

## 节点安装 AAVMF 并添加到 pflashes 文件
1. AAVMF_CODE.fd、AAVMF_VARS.fd 文件位于包 edk2-aarch64 中。下载地址：
```sh
# 包地址
https://pkgs.org/download/AAVMF
# 实际使用的 edk2 包
https://almalinux.pkgs.org/9/almalinux-appstream-aarch64/edk2-aarch64-20230524-4.el9_3.noarch.rpm.html
# 下载后，查看包内容：
rpm -qpl edk2-aarch64-20230524-4.el9_3.noarch.rpm
...
/usr/share/AAVMF                      
/usr/share/AAVMF/AAVMF_CODE.fd        
/usr/share/AAVMF/AAVMF_CODE.verbose.fd
/usr/share/AAVMF/AAVMF_VARS.fd
...
```

2. 安装 rpm 包
```sh
yum localinstall edk2-aarch64-20230524-4.el9_3.noarch.rpm
```

3. 拷贝 AAVMF_* 文件
```sh
mkdir -p /usr/share/kata-containers/AAVMF/
cp -f /usr/share/edk2/aarch64/QEMU_EFI-silent-pflash.raw /usr/share/kata-containers/AAVMF/AAVMF_CODE.fd
cp -f /usr/share/edk2/aarch64/vars-template-pflash.raw /usr/share/kata-containers/AAVMF/AAVMF_VARS.fd
```

4. 在 kata 配置文件中，配置 pflashes
```sh
pflashes = ["/usr/share/kata-containers/AAVMF/AAVMF_CODE.fd","/usr/share/kata-containers/AAVMF/AAVMF_VARS.fd"]
```

## 编译安装 musl-gcc
```sh
# 下载
wget https://musl.libc.org/releases/musl-1.2.4.tar.gz
# 解压
tar xf musl-1.2.4.tar.gz
# 编译
cd musl-1.2.4
./configure
# 安装
make
## 安装目录
/usr/local/musl/bin/musl-gcc
# 软链接
ln -s /usr/local/musl/bin/musl-gcc /usr/bin/$(uname -m)-linux-musl-gcc
```
**备注**：musl libc release：https://musl.libc.org/releases.html

## 编译 kata-agent
```sh
# 切换目录
cd go/src/github.com/kata-containers/kata-containers/src/agent
# 编译 kata-agent、kata-agent.service
make -e SECCOMP=no -e LIBC=musl kata-agent
make kata-agent.service
```
**注意**：Rust 1.69.0 安装文档：https://www.rust-lang.org/tools/install

## 编译内核 vmlinux
1. 添加 npu.conf
```sh
$ cd go/src/github.com/kata-containers/kata-containers/tools/packaging/kernel
$ cat > configs/fragments/arm64/npu.conf << EOF
# Support for loading modules.
# It is used to support loading GPU drivers.
CONFIG_MODULES=y
CONFIG_MODULE_UNLOAD=y

# CRYPTO_FIPS requires this config when loading modules is enabled.
CONFIG_MODULE_SIG=y

# Support the DMI and PCI iov
CONFIG_DMI=y
CONFIG_PCI_IOV=y
CONFIG_PCI_PRI=y
CONFIG_PCI_PASID=y

# Support the KVM   
CONFIG_KVM=y
CONFIG_HAVE_KVM_IRQCHIP=y
CONFIG_HAVE_KVM_IRQFD=y
CONFIG_HAVE_KVM_IRQ_ROUTING=y
CONFIG_HAVE_KVM_EVENTFD=y
CONFIG_KVM_MMIO=y
CONFIG_HAVE_KVM_MSI=y
CONFIG_HAVE_KVM_CPU_RELAX_INTERCEPT=y
CONFIG_KVM_VFIO=y
CONFIG_HAVE_KVM_ARCH_TLB_FLUSH_ALL=y
CONFIG_KVM_GENERIC_DIRTYLOG_READ_PROTECT=y
CONFIG_HAVE_KVM_IRQ_BYPASS=y
CONFIG_HAVE_KVM_VCPU_RUN_PID_CHANGE=y
CONFIG_KVM_XFER_TO_GUEST_WORK=y

CONFIG_KVM_VFIO=y
CONFIG_VFIO=y
CONFIG_VFIO_IOMMU_TYPE1=y
CONFIG_VFIO_VIRQFD=y
CONFIG_VFIO_PCI_CORE=y
CONFIG_VFIO_PCI_MMAP=y
CONFIG_VFIO_PCI_INTX=y
CONFIG_VFIO_PCI=y
CONFIG_VFIO_MDEV=m
EOF
```

2. 安装必要工具
```sh
dnf install gcc make openssl pkg-config bison flex bc ca-certificates patch elfutils-devel openssl-devel xz diffutils perl
```

3. 编译内核
```sh
# setup
./build-kernel.sh -v 5.15.63 -f -g nvidia -d setup
# build
./build-kernel.sh -v 5.15.63 -f -g nvidia -d build
# install
./build-kernel.sh -v 5.15.63 -f -g nvidia -d install
# 目录
/usr/share/kata-containers/vmlinux.container
/usr/share/kata-containers/vmlinuz.container
```

4. 编译内核开发包
```sh
# 安装必要工具
dnf install rpm-build rsync
# 构建 deb 包（因为目标镜像为 ubuntu）
cd kata-linux-5.15.63-114/
make deb-pkg
# 目标产物
ls /root/rpmbuild/RPMS/aarch64/
kernel-5.15.63-2.aarch64.deb kernel-devel-5.15.63-2.aarch64.deb  kernel-headers-5.15.63-2.aarch64.deb
```

## 编译虚拟机镜像 kata-containers.img
1. 安装必要工具
```sh
dnf install qemu-img 
```

2. 编译文件系统 ubuntu rootfs
```sh
export USE_DOCKER=true
export EXTRA_PKGS="chrony make curl pciutils apt dpkg python3 software-properties-common kmod net-tools udev build-essential vim"
export ROOTFS_DIR=${GOPATH}/src/github.com/kata-containers/kata-containers/tools/osbuilder/rootfs-builder/ubuntu-rootfs
export AGENT_SOURCE_BIN="${GOPATH}/src/github.com/kata-containers/kata-containers/src/agent/target/aarch64-unknown-linux-musl/release/kata-agent"
cd ${GOPATH}/src/github.com/kata-containers/kata-containers/tools/osbuilder/rootfs-builder
./rootfs.sh ubuntu
```

3. 编译虚拟机镜像
```sh
cd ..
cp ../../src/agent/kata-agent.service rootfs-builder/ubuntu-rootfs/etc/systemd/system/
cp ../../src/agent/kata-containers.target rootfs-builder/ubuntu-rootfs/etc/systemd/system/
./image-builder/image_builder.sh rootfs-builder/ubuntu-rootfs
# 目标产物
./kata-containers.img
```

## 验证 NPU 直通
1. 启动安全容器并挂载设备
```sh
# --device 指定设备
ctr --debug -n k8s.io run --rm --runtime "io.containerd.kata.v2" --device /dev/vfio/64 -t  "docker.io/library/ubuntu:22.04" test bash
```

2. 查看设备挂载情况
```sh
[root@modelfoundry-funcverif-machine-001 ~]# /opt/kata/bin/kata-runtime exec test
bash-5.1# lspci                                               
00:00.0 Host bridge: Red Hat, Inc. QEMU PCIe Host bridge      
00:01.0 Communication controller: Red Hat, Inc. Virtio console
00:02.0 PCI bridge: Red Hat, Inc. QEMU PCI-PCI bridge         
00:03.0 SCSI storage controller: Red Hat, Inc. Virtio SCSI    
00:04.0 Unclassified device [00ff]: Red Hat, Inc. Virtio RNG  
00:05.0 PCI bridge: Red Hat, Inc. QEMU PCIe Root port         
00:06.0 Communication controller: Red Hat, Inc. Virtio 1.0 socket (rev 01)
00:07.0 Unclassified device [0002]: Red Hat, Inc. Virtio filesystem       
02:00.0 Processing accelerators: Huawei Technologies Co., Ltd. Device d802 (rev 20) <-- 实际 NPU 卡
```
NPU 直通生效，由于虚拟机缺少 Ascend NPU 驱动，暂时功能不可用。

## 虚拟机 rootfs 增加 NPU 驱动
在步骤`编译虚拟机镜像` kata-containers.img 中已经获取 rootfs。在步骤`编译内核 vmlinux`已获取内核驱动编译依赖包。

1. 准备文件
```sh
# 拷贝 kernel-devel
cp /root/rpmbuild/RPMS/aarch64/kernel-devel-5.15.63-2.aarch64.rpm ${GOPATH}/src/github.com/kata-containers/kata-containers/tools/osbuilder/rootfs-builder/ubuntu-rootfs/root/
# 拷贝驱动安装包
cp /root/kata/Ascend/Ascend-hdk-910b-npu-driver_23.0.rc3_linux-aarch64.run  ${GOPATH}/src/github.com/kata-containers/kata-containers/tools/osbuilder/rootfs-builder/ubuntu-rootfs/root/
*Ascend HDK 驱动下载地址：https://www.hiascend.com/zh/hardware/firmware-drivers/commercial?product=4&model=11
```

2. 切换目录
```sh
cd ${GOPATH}/src/github.com/kata-containers/kata-containers/tools/osbuilder/rootfs-builder/

export ROOTFS_DIR=ubuntu-rootfs
mount -t sysfs -o ro none ${ROOTFS_DIR}/sys
mount -t proc -o ro none ${ROOTFS_DIR}/proc
mount -o bind,ro /dev ${ROOTFS_DIR}/dev
mount -t devpts none ${ROOTFS_DIR}/dev/pts
mount -t tmpfs none ${ROOTFS_DIR}/tmp
chroot ${ROOTFS_DIR}
```

**注意**：操作完成记得卸载目录
```sh
export ROOTFS_DIR=ubuntu-rootfs
umount ${ROOTFS_DIR}/sys
umount ${ROOTFS_DIR}/proc
umount ${ROOTFS_DIR}/dev/pts
umount ${ROOTFS_DIR}/dev
umount ${ROOTFS_DIR}/tmp
```

3. 安装驱动
```sh
# 安装 kernel-devel
yum install /root/kernel-devel-5.15.63-2.aarch64.rpm
# 编译安装驱动
groupadd HwHiAiUser
useradd -g HwHiAiUser -d /home/HwHiAiUser -m HwHiAiUser -s /bin/bash
yum install -y tar procps-ng kmod which e2fsprogs net-tools findutils systemd-udev chkconfig gcc 
dnf install -y epel-release epel-next-release
dnf install -y dkms

/root/Ascend-hdk-910b-npu-driver_23.0.rc3_linux-aarch64.run --full --install-for-all
```

## Kata Prestart Hook
Prestart hook 配置：
```json
{
    "path": "/usr/local/Ascend/Ascend-Docker-Runtime/ascend-docker-hook",
    "args": [
        "/usr/local/Ascend/Ascend-Docker-Runtime/ascend-docker-hook"
    ],
    "env": null,
    "dir": "",
    "timeout": null
}
```
- 项目地址：https://gitee.com/ascend/ascend-docker-runtime
- 下载地址：https://gitee.com/ascend/ascend-docker-runtime/releases
- 项目文档：https://www.hiascend.com/document/detail/zh/mindx-dl/50rc2/dockerruntime/dockerruntimeug/dlruntime_ug_006.html

## k8s-device-plugin
TODO

# 裸金属机器及操作系统等信息
## 操作系统
```sh
NAME="EulerOS"
VERSION="2.0 (SP10)"
ID="euleros"
VERSION_ID="2.0"
PRETTY_NAME="EulerOS 2.0 (SP10)"
ANSI_COLOR="0;31"
```

## CPU 信息
```sh
Architecture: aarch64
CPU op-mode(s): 64-bit
Byte Order: Little Endian
CPU(s): 192
On-line CPU(s) list: 0-191
Thread(s) per core: 1
Core(s) per socket: 48
Socket(s): 4
NUMA node(s): 8
Vendor ID: HiSilicon
Model: 0
Model name: Kunpeng-920
Stepping: 0x1
BogoMIPS: 200.00
L1d cache: 12 MiB
L1i cache: 12 MiB
L2 cache: 96 MiB
L3 cache: 192 MiB
NUMA node0 CPU(s): 0-23
NUMA node1 CPU(s): 24-47
NUMA node2 CPU(s): 48-71
NUMA node3 CPU(s): 72-95
NUMA node4 CPU(s): 96-119
NUMA node5 CPU(s): 120-143
NUMA node6 CPU(s): 144-167
NUMA node7 CPU(s): 168-191 
Vulnerability Gather data sampling: Not affected
Vulnerability Itlb multihit: Not affected
Vulnerability L1tf: Not affected
Vulnerability Mds: Not affected
Vulnerability Meltdown: Not affected
Vulnerability Mmio stale data: Not affected
Vulnerability Retbleed: Not affected
Vulnerability Spec store bypass: Mitigation; Speculative Store Bypass disabled via prctl
Vulnerability Spectre v1: Mitigation; __user pointer sanitization
Vulnerability Spectre v2: Not affected
Vulnerability Srbds: Not affected
Vulnerability Tsx async abort: Not affected
Flags: fp asimd evtstrm aes pmull sha1 sha2 crc32 atomics fphp asimdhp cpuid asimdrdm jscvt fcma dcpop asimddp asimdfhm ss bs
```
## Ascend NPU 卡信息
```sh
[root@modelfoundry-funcverif-machine-001 ~]# lspci | grep -i d802
01:00.0 Processing accelerators: Huawei Technologies Co., Ltd. Device d802 (rev 20)
02:00.0 Processing accelerators: Huawei Technologies Co., Ltd. Device d802 (rev 20)
41:00.0 Processing accelerators: Huawei Technologies Co., Ltd. Device d802 (rev 20)
42:00.0 Processing accelerators: Huawei Technologies Co., Ltd. Device d802 (rev 20)
81:00.0 Processing accelerators: Huawei Technologies Co., Ltd. Device d802 (rev 20)
82:00.0 Processing accelerators: Huawei Technologies Co., Ltd. Device d802 (rev 20)
c1:00.0 Processing accelerators: Huawei Technologies Co., Ltd. Device d802 (rev 20)
c2:00.0 Processing accelerators: Huawei Technologies Co., Ltd. Device d802 (rev 20)
[root@modelfoundry-funcverif-machine-001 ~]# npu-smi info
+------------------------------------------------------------------------------------------------+
| npu-smi 23.0.rc3                 Version: 23.0.rc3                                             |
+---------------------------+---------------+----------------------------------------------------+
| NPU   Name                | Health        | Power(W)    Temp(C)           Hugepages-Usage(page)|
| Chip                      | Bus-Id        | AICore(%)   Memory-Usage(MB)  HBM-Usage(MB)        |
+===========================+===============+====================================================+
| 0     910B4               | OK            | 82.6        47                0    / 0             |
| 0                         | 0000:C1:00.0  | 0           0    / 0          3127 / 32768         |
+===========================+===============+====================================================+
| 1     910B4               | OK            | 81.6        50                0    / 0             |
| 0                         | 0000:01:00.0  | 0           0    / 0          3128 / 32768         |
+===========================+===============+====================================================+
| 2     910B4               | OK            | 81.0        49                0    / 0             |
| 0                         | 0000:C2:00.0  | 0           0    / 0          3128 / 32768         |
+===========================+===============+====================================================+
| 3     910B4               | OK            | 83.8        48                0    / 0             |
| 0                         | 0000:02:00.0  | 0           0    / 0          3128 / 32768         |
+===========================+===============+====================================================+
| 4     910B4               | OK            | 83.8        47                0    / 0             |
| 0                         | 0000:81:00.0  | 0           0    / 0          3128 / 32768         |
+===========================+===============+====================================================+
| 5     910B4               | OK            | 83.8        48                0    / 0             |
| 0                         | 0000:41:00.0  | 0           0    / 0          3128 / 32768         |
+===========================+===============+====================================================+
| 6     910B4               | OK            | 90.4        47                0    / 0             |
| 0                         | 0000:82:00.0  | 0           0    / 0          3128 / 32768         |
+===========================+===============+====================================================+
| 7     910B4               | OK            | 83.7        48                0    / 0             |
| 0                         | 0000:42:00.0  | 0           0    / 0          3129 / 32768         |
+===========================+===============+====================================================+
```

## Ascend NPU 详细信息
```sh
01:00.0 Processing accelerators: Huawei Technologies Co., Ltd. Device d802 (rev 20)                          
        Subsystem: Huawei Technologies Co., Ltd. Device 3002                                                 
        Control: I/O- Mem+ BusMaster+ SpecCycle- MemWINV- VGASnoop- ParErr+ Stepping- SERR+ FastB2B- DisINTx+
        Status: Cap+ 66MHz- UDF- FastB2B- ParErr- DEVSEL=fast >TAbort- <TAbort- <MAbort- >SERR- <PERR- INTx- 
        Latency: 0, Cache Line Size: 32 bytes                             
        Interrupt: pin A routed to IRQ 102                                
        NUMA node: 0                                                      
        Region 0: Memory at 83c20000000 (64-bit, prefetchable) [size=512M]
        Region 2: Memory at 83c00000000 (64-bit, prefetchable) [size=512M]
        Region 4: Memory at 82000000000 (64-bit, prefetchable) [size=64G] 
        Capabilities: [40] Express (v2) Endpoint, MSI 00                  
                DevCap: MaxPayload 256 bytes, PhantFunc 0, Latency L0s unlimited, L1 unlimited
                        ExtTag+ AttnBtn- AttnInd- PwrInd- RBE+ FLReset- SlotPowerLimit 25.000W
                DevCtl: CorrErr+ NonFatalErr+ FatalErr+ UnsupReq+   
                        RlxdOrd+ ExtTag+ PhantFunc- AuxPwr- NoSnoop-
                        MaxPayload 256 bytes, MaxReadReq 512 bytes  
                DevSta: CorrErr+ NonFatalErr- FatalErr- UnsupReq+ AuxPwr+ TransPend-          
                LnkCap: Port #0, Speed 32GT/s, Width x16, ASPM L0s L1, Exit Latency L0s <4us, L1 <8us
                        ClockPM- Surprise- LLActRep- BwNot- ASPMOptComp+
                LnkCtl: ASPM Disabled; RCB 128 bytes Disabled- CommClk- 
                        ExtSynch- ClockPM- AutWidDis- BWInt- AutBWInt-  
                LnkSta: Speed 16GT/s (downgraded), Width x16 (ok)       
                        TrErr- Train- SlotClk- DLActive- BWMgmt- ABWMgmt- 
                DevCap2: Completion Timeout: Range BCD, TimeoutDis+, NROPrPrP-, LTR-
                         10BitTagComp-, 10BitTagReq-, OBFF Not Supported, ExtFmt+, EETLPPrefix-
                         EmergencyPowerReduction Not Supported, EmergencyPowerReductionInit-
                         FRS-, TPHComp-, ExtTPHComp-           
                         AtomicOpsCap: 32bit- 64bit- 128bitCAS-
                DevCtl2: Completion Timeout: 4s to 13s, TimeoutDis-, LTR-, OBFF Disabled
                         AtomicOpsCtl: ReqEn-
                LnkCtl2: Target Link Speed: 32GT/s, EnterCompliance- SpeedDis-          
                         Transmit Margin: Normal Operating Range, EnterModifiedCompliance- ComplianceSOS-
                         Compliance De-emphasis: -6dB
                LnkSta2: Current De-emphasis Level: -3.5dB, EqualizationComplete+, EqualizationPhase1+
                         EqualizationPhase2+, EqualizationPhase3+, LinkEqualizationRequest-
        Capabilities: [a0] MSI-X: Enable+ Count=256 Masked-
                Vector table: BAR=0 offset=1fff0000        
                PBA: BAR=0 offset=1fff4000                 
        Capabilities: [b0] Power Management version 3      
                Flags: PMEClk- DSI- D1- D2- AuxCurrent=0mA PME(D0-,D1-,D2-,D3hot-,D3cold-) 
                Status: D0 NoSoftRst+ PME-Enable- DSel=0 DScale=0 PME-                     
        Capabilities: [100 v2] Advanced Error Reporting                                    
                UESta:  DLP- SDES- TLP- FCP- CmpltTO- CmpltAbrt- UnxCmplt- RxOF- MalfTLP- ECRC- UnsupReq- ACSViol-
                UEMsk:  DLP- SDES- TLP- FCP- CmpltTO- CmpltAbrt- UnxCmplt- RxOF- MalfTLP- ECRC- UnsupReq+ ACSViol-
                UESvrt: DLP- SDES- TLP- FCP- CmpltTO- CmpltAbrt- UnxCmplt- RxOF- MalfTLP- ECRC- UnsupReq- ACSViol-
                CESta:  RxErr- BadTLP- BadDLLP- Rollover- Timeout- AdvNonFatalErr+            
                CEMsk:  RxErr- BadTLP- BadDLLP- Rollover- Timeout- AdvNonFatalErr+            
                AERCap: First Error Pointer: 00, ECRCGenCap+ ECRCGenEn- ECRCChkCap+ ECRCChkEn-
                        MultHdrRecCap- MultHdrRecEn- TLPPfxPres- HdrLogCap-
                HeaderLog: 04000001 0000000f 01010000 85a9d217             
        Capabilities: [150 v1] Alternative Routing-ID Interpretation (ARI) 
                ARICap: MFVC- ACS-, Next Function: 1                       
                ARICtl: MFVC- ACS-, Function Group: 0                      
        Capabilities: [1a0 v1] Extended Capability ID 0x2e                 
        Capabilities: [200 v1] Single Root I/O Virtualization (SR-IOV)     
                IOVCap: Migration-, Interrupt Message Number: 000          
                IOVCtl: Enable- Migration- Interrupt- MSE- ARIHierarchy+   
                IOVSta: Migration-                                         
                Initial VFs: 12, Total VFs: 12, Number of VFs: 0, Function Dependency Link: 00
                VF offset: 4, stride: 1, Device ID: d802                   
                Supported Page Size: 00000553, System Page Size: 00000001  
                Region 0: Memory at 0000083c70000000 (64-bit, prefetchable)
                Region 2: Memory at 0000083c40000000 (64-bit, prefetchable)
                Region 4: Memory at 0000083000000000 (64-bit, prefetchable)
                VF Migration: offset: 00000000, BIR: 0                     
        Capabilities: [2a0 v1] Transaction Processing Hints                
                Device specific mode supported                             
                No steering table available                                
        Capabilities: [310 v1] Secondary PCI Express                       
                LnkCtl3: LnkEquIntrruptEn-, PerformEqu-                    
                LaneErrStat: 0                                             
        Capabilities: [3c0 v2] L1 PM Substates                             
                L1SubCap: PCI-PM_L1.2+ PCI-PM_L1.1+ ASPM_L1.2+ ASPM_L1.1+ L1_PM_Substates+
                          PortCommonModeRestoreTime=1us PortTPowerOnTime=10us
                L1SubCtl1: PCI-PM_L1.2- PCI-PM_L1.1- ASPM_L1.2- ASPM_L1.1-   
                           T_CommonMode=0us LTR1.2_Threshold=0ns             
                L1SubCtl2: T_PwrOn=10us                                      
        Capabilities: [4e0 v1] Device Serial Number 04-02-20-02-04-02-20-02  
        Capabilities: [630 v1] Access Control Services                       
                ACSCap: SrcValid- TransBlk- ReqRedir- CmpltRedir- UpstreamFwd- EgressCtrl- DirectTrans-
                ACSCtl: SrcValid- TransBlk- ReqRedir- CmpltRedir- UpstreamFwd- EgressCtrl- DirectTrans-
        Capabilities: [6d0 v1] Latency Tolerance Reporting       
                Max snoop latency: 0ns                           
                Max no snoop latency: 0ns                        
        Capabilities: [700 v1] Data Link Feature <?>             
        Capabilities: [70c v1] Lane Margining at the Receiver <?>
        Capabilities: [780 v1] Extended Capability ID 0x2a       
        Capabilities: [880 v1] Physical Layer 16.0 GT/s <?>      
        Kernel driver in use: devdrv_device_driver               
        Kernel modules: drv_vascend, dbl_runenv_config, drv_devmm_host, drv_devmm_host_agent, ascend_event_sched_host, drv_devmng_host, drv_pcie_hdc_ho
st, ascend_trs_sec_eh_agent, ascend_trs_sub_stars, ascend_queue, drv_davinci_intf_host, ts_agent, ascend_trs_pm_adapt, dbl_dev_identity, dbl_algorithm,
 drv_soft_fault, ascend_soc_platform, drv_dvpp_cmdlist, drv_pcie_host, drv_pcie_vnic_host, ascend_trs_shrid, drv_dp_proc_mng_host, ascend_xsmem, drv_vi
rtmng_host
```
