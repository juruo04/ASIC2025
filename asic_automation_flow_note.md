# 从零开始体验 ASIC 自动化流程

本文档面向第一次接触 ASIC 开源流程的同学，目标是在 Linux 系统上把一份可综合 RTL 交给 Yosys/LibreLane，最终生成 GDS2 Layout。这里的目标是体验流程，不是直接达到真实流片 sign-off 标准。

## 1. 先解释 FPGA 功耗为什么看起来有 100 mW

Vivado routed 后报告中的总片上功耗约为 0.120 W，也就是 120 mW。这个数值看起来有点大，但对 ZYNQ-7020 FPGA 来说是正常的，因为大头来自芯片静态功耗。

| 项目 | 数值 |
| --- | ---: |
| Total On-Chip Power | 0.120 W |
| Dynamic Power | 0.014 W |
| Device Static Power | 0.106 W |
| Junction Temperature | 26.4 $^\circ$C |
| Confidence Level | Medium |

也就是说，本设计 RTL 真正动态翻转产生的功耗大约只有 14 mW；总功耗里的 106 mW 是 FPGA 器件静态功耗。报告里可以写：本设计 routed 后估计片上总功耗约为 0.120 W，其中动态功耗约 0.014 W，主要功耗来自 FPGA 静态功耗。

## 2. 你需要准备什么

建议使用 Ubuntu 22.04 或 Ubuntu 24.04。可以是真机、虚拟机，也可以是 WSL2。新手最推荐：Windows + WSL2 Ubuntu。

需要安装的软件：

1. Git：下载代码和管理文件。
2. Docker：运行 LibreLane 容器，避免手动安装一大堆 EDA 工具。
3. Python/pipx：部分 LibreLane 安装方式会用到。
4. KLayout：查看最终 GDS 版图。

最省事的路线是：用 Docker 跑 LibreLane。

## 3. 如果你在 Windows 上，先安装 WSL2

用管理员 PowerShell 运行：

```powershell
wsl --install -d Ubuntu-22.04
```

安装完成后重启电脑，打开 Ubuntu 终端，创建 Linux 用户名和密码。

进入 Ubuntu 后先更新系统：

```bash
sudo apt update
sudo apt upgrade -y
```

如果你已经有 Ubuntu 真机或虚拟机，就从这里继续。

## 4. 安装基础工具

在 Ubuntu 终端运行：

```bash
sudo apt update
sudo apt install -y git curl wget make python3 python3-pip python3-venv pipx klayout
```

让 `pipx` 加入 PATH：

```bash
pipx ensurepath
```

执行后关闭当前终端，再重新打开一个 Ubuntu 终端。

## 5. 安装 Docker

先安装依赖：

```bash
sudo apt install -y ca-certificates curl gnupg
```

添加 Docker 官方源：

```bash
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
```

添加 apt 源：

```bash
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

安装 Docker：

```bash
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

把当前用户加入 docker 组，这样以后不用每次 `sudo docker`：

```bash
sudo usermod -aG docker $USER
```

然后退出 Ubuntu，再重新打开 Ubuntu。测试 Docker：

```bash
docker run hello-world
```

如果能看到 hello-world 的说明，Docker 就好了。

## 6. 拉取 LibreLane 容器

LibreLane 镜像比较大，下载需要一点时间：

```bash
docker pull ghcr.io/efabless/librelane:latest
```

测试是否能运行：

```bash
docker run --rm ghcr.io/efabless/librelane:latest librelane --version
```

如果这个镜像名因为版本变化不可用，可以查 LibreLane 官方文档；但流程思想不变：用 Docker 镜像启动 LibreLane。

## 7. 建立 ASIC 实验目录

选择一个工作目录，比如家目录下：

```bash
mkdir -p ~/asic_reaction_demo/rtl
cd ~/asic_reaction_demo
```

把你的 RTL 文件复制进 `rtl/`。如果你的工程在 Windows 磁盘，WSL 中一般可以通过 `/mnt/d/...` 访问。例如：

```bash
cp /mnt/d/FDU/Courses/3B/ASIC/PJ/src/*.v rtl/
```

为了避免 testbench 混进去，只保留设计文件：

```bash
ls rtl
```

推荐保留这些文件：

```text
button_debounce_pulse.v
lfsr_random_service.v
ms_counter_service.v
score_history_avg.v
reaction_controller.v
reaction_core.v
seg7_display_driver.v
buzzer_driver.v
reaction_system_top.v
```

不要放 testbench，比如 `*_tb.v` 不要放进 LibreLane 综合列表。

## 8. 为什么要改成 Yosys 能读的格式

Vivado 支持的 Verilog/SystemVerilog 语法比较宽，Yosys 支持的是可综合子集。别人说“把原有 SV 转译成 Yosys 可读取的 SV 格式”，意思就是：

1. 不改变模块功能。
2. 不改变顶层接口。
3. 去掉仿真专用语法。
4. 避开旧工具不支持的 SystemVerilog 写法。

常见处理如下：

| Vivado 里可能能用的写法 | Yosys 兼容处理 |
| --- | --- |
| `string` / dynamic string | 删除，或改成固定宽度参数 |
| testbench 的 `$display`、`#10`、`initial` 激励 | 不放进综合 RTL |
| `always_ff` | 改成 `always @(posedge clk or negedge rst_n)` |
| `always_comb` | 改成 `always @(*)` |
| FPGA IP 或 primitive | 改成普通 RTL |
| 依赖寄存器初值 | 改成 reset 赋值 |

可以让 opencode/Copilot 帮你做这件事，提示词可以写：

```text
请把这些 Vivado 可综合 SystemVerilog/Verilog 文件整理为 Yosys 可读取的可综合 RTL 子集。
要求：不改变模块端口和行为；删除仿真专用语法；不要使用 dynamic string；尽量使用 Verilog-2005 风格 always 块。
```

## 9. 先单独用 Yosys 检查 RTL

LibreLane 里面会调用 Yosys，但新手建议先自己跑一次 Yosys 读入检查。可以用 LibreLane 容器里的工具跑：

```bash
cd ~/asic_reaction_demo
docker run --rm -it \
  -v "$PWD":/work \
  -w /work \
  ghcr.io/efabless/librelane:latest \
  yosys -p "read_verilog -sv rtl/*.v; hierarchy -top reaction_system_top; proc; opt; stat"
```

如果成功，你会看到综合统计信息。如果失败，常见错误是某个语法 Yosys 不认识，需要回到 RTL 继续改。

## 10. 写 LibreLane 配置文件

在 `~/asic_reaction_demo` 下创建 `config.yaml`：

```bash
nano config.yaml
```

填入下面内容：

```yaml
DESIGN_NAME: reaction_system_top
VERILOG_FILES:
  - dir::rtl/button_debounce_pulse.v
  - dir::rtl/lfsr_random_service.v
  - dir::rtl/ms_counter_service.v
  - dir::rtl/score_history_avg.v
  - dir::rtl/reaction_controller.v
  - dir::rtl/reaction_core.v
  - dir::rtl/seg7_display_driver.v
  - dir::rtl/buzzer_driver.v
  - dir::rtl/reaction_system_top.v
CLOCK_PORT: clk
CLOCK_PERIOD: 20
FP_SIZING: absolute
DIE_AREA: [0, 0, 1500, 1500]
PL_TARGET_DENSITY: 0.45
```

保存 nano：按 `Ctrl+O`，回车，再按 `Ctrl+X` 退出。

说明：

- `DESIGN_NAME` 是顶层模块名。
- `CLOCK_PORT` 是时钟端口名。
- `CLOCK_PERIOD: 20` 表示 20 ns，也就是 50 MHz。
- `DIE_AREA` 是给一个初始芯片面积。太小可能放不下，初学先给大一点。
- `PL_TARGET_DENSITY` 是布局密度。太高容易布线失败，初学先保守一点。

## 11. 写时钟约束文件

有些 LibreLane 版本直接读 `CLOCK_PORT/CLOCK_PERIOD` 就够了，但写一个 SDC 更清楚。

创建 `constraints.sdc`：

```bash
nano constraints.sdc
```

填入：

```tcl
create_clock -name clk -period 20 [get_ports clk]
```

保存退出。

如果 LibreLane 版本需要在 config 里显式指定 SDC，可以加：

```yaml
PNR_SDC_FILE: dir::constraints.sdc
SIGNOFF_SDC_FILE: dir::constraints.sdc
```

不同版本字段可能略有变化，如果报配置字段错误，就先删掉这两行，只保留 `CLOCK_PORT` 和 `CLOCK_PERIOD`。

## 12. 运行 LibreLane

在工程目录运行：

```bash
cd ~/asic_reaction_demo
docker run --rm -it \
  -v "$PWD":/work \
  -w /work \
  ghcr.io/efabless/librelane:latest \
  librelane config.yaml
```

如果流程开始跑，你会看到类似综合、floorplan、placement、CTS、routing、signoff 的阶段输出。

这个过程可能需要几分钟到几十分钟，取决于电脑性能和设计规模。

## 13. 跑完后看哪里

LibreLane 会生成 runs 目录。可以用：

```bash
find . -maxdepth 3 -type d
```

找最新的 run。常见输出会在类似目录中：

```text
runs/<run_name>/final/
runs/<run_name>/reports/
runs/<run_name>/logs/
```

找 GDS 文件：

```bash
find runs -name "*.gds" -o -name "*.gds2"
```

找报告：

```bash
find runs -name "*.rpt" | head
```

如果看到 `.gds` 或 `.gds2`，说明版图文件已经生成。

## 14. 用 KLayout 打开 GDS

如果你在 Ubuntu 桌面环境中，可以直接：

```bash
klayout path/to/final.gds
```

如果你在 WSL2 且 Windows 已支持 GUI，也可以尝试直接运行 `klayout`。如果 GUI 不方便，可以把 GDS 文件复制回 Windows，用 Windows 版 KLayout 打开。

在 WSL 中复制到 Windows 桌面示例：

```bash
cp path/to/final.gds /mnt/c/Users/<你的Windows用户名>/Desktop/
```

打开后可以截图，用作报告里的 “GDS2 Layout” 展示图。

## 15. 常见报错怎么处理

### 15.1 Docker 权限错误

如果运行 docker 提示 permission denied，执行：

```bash
sudo usermod -aG docker $USER
```

然后退出 Ubuntu，重新打开。

### 15.2 Yosys 读不懂语法

先看报错文件和行号。常见处理：

- 删除 `string`。
- 删除 testbench。
- 把 `always_ff` 改成普通 `always`。
- 把 `initial` 初始化改成 reset。
- 避免复杂 SystemVerilog 类型。

### 15.3 面积太小放不下

如果 placement 报放不下，增大 `DIE_AREA`，例如：

```yaml
DIE_AREA: [0, 0, 2500, 2500]
PL_TARGET_DENSITY: 0.35
```

### 15.4 布线失败

降低密度或增大面积：

```yaml
PL_TARGET_DENSITY: 0.30
DIE_AREA: [0, 0, 3000, 3000]
```

### 15.5 时序不满足

先把时钟周期放宽，比如从 20 ns 改成 50 ns：

```yaml
CLOCK_PERIOD: 50
```

能跑通流程后，再慢慢优化设计。

## 16. 报告里可以怎么写

可以写成下面这段：

> 为了进一步体验 ASIC 自动化设计流程，本文在完成 FPGA 实现的基础上，尝试将原有 SystemVerilog/Verilog RTL 整理为 Yosys 可读取的可综合子集。由于部分开源工具对 dynamic string、仿真语句以及复杂 SystemVerilog 语法支持有限，因此对 RTL 进行了兼容性改写，保留模块接口和主要时序行为。随后在 Linux 环境下使用 Docker 运行 LibreLane，调用 Yosys、OpenROAD、Magic/KLayout 等开源工具，完成逻辑综合、floorplan、placement、routing、DRC/LVS 检查，并成功生成 GDS2 Layout。该流程主要用于课程拓展和 ASIC EDA 自动化流程体验，尚未作为真实流片 sign-off 结果。

如果要配图，可以放：

1. LibreLane 终端运行成功截图。
2. KLayout 打开的 GDS2 版图截图。
3. 简单的 flow 图：RTL -> Yosys -> OpenROAD -> GDS2。

## 17. 最短命令清单

如果只想看命令，按这个顺序：

```bash
sudo apt update
sudo apt install -y git curl wget make python3 python3-pip python3-venv pipx klayout ca-certificates gnupg

sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker $USER
```

重新打开终端后：

```bash
docker run hello-world
docker pull ghcr.io/efabless/librelane:latest

mkdir -p ~/asic_reaction_demo/rtl
cd ~/asic_reaction_demo
cp /mnt/d/FDU/Courses/3B/ASIC/PJ/src/*.v rtl/

docker run --rm -it -v "$PWD":/work -w /work ghcr.io/efabless/librelane:latest yosys -p "read_verilog -sv rtl/*.v; hierarchy -top reaction_system_top; proc; opt; stat"
```

再写好 `config.yaml` 后运行：

```bash
docker run --rm -it -v "$PWD":/work -w /work ghcr.io/efabless/librelane:latest librelane config.yaml
```

最后找 GDS：

```bash
find runs -name "*.gds" -o -name "*.gds2"
```
