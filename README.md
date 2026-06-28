# ASIC2025 人体反应速度测试器

本项目基于 FPGA（ZYNQ-Z7020）实现一个人体反应速度测试器，支持随机等待、反应时间测量、失败判定、历史成绩平均显示与蜂鸣提示。

## 功能概览

- START 后进入随机等待阶段
- 到达提示时刻后测量 REACT 按键反应时间
- 过早按键或超时显示 FAIL
- 支持最近三次有效成绩平均值显示
- 有源蜂鸣器低有效短鸣提示（非 PWM）

## 目录结构

- src/: RTL 设计源码
- sim/: 各模块测试平台
- xdc/: 引脚与时钟约束
- report/: 课程报告与相关素材
- Vivado/: 工程文件与实现结果
- requirements.md: 需求说明
- 演示.mp4: 项目演示视频

## 开发与验证环境

- 开发板: ZYNQ-Z7020（xc7z020clg484-2）
- 工具: Vivado 2019.1
- 报告编译: XeLaTeX

## 报告编译

在 report 目录执行：

```bash
xelatex -interaction=nonstopmode -file-line-error course_report.tex
xelatex -interaction=nonstopmode -file-line-error course_report.tex
```

## 说明

项目采用 Top-Down 设计方法，先进行系统级需求拆分与接口定义，再完成模块实现、仿真验证、综合实现与板级联调。