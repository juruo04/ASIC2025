## 设计实现与分模块仿真（可转 TeX）

### 1. 毫秒计数模块 ms_counter_service

实现说明：
该模块本质是加法计数器。系统时钟经过分频后形成 1 ms 计数节拍，在 counter_en 有效时对 ms_counter 自增，在 counter_clr 有效时立即清零。

仿真目标：
1. 复位后 ms_counter 为 0。
2. counter_en=1 时按毫秒节拍递增。
3. counter_clr=1 时计数器清零。

波形关注信号：clk、rst_n、counter_en、counter_clr、ms_counter。

### 2. 随机等待模块 lfsr_random_service

实现说明：
采用 LFSR 伪随机序列发生器。其递推可写为：
$$
x_{k+1} = A x_k
$$
其中反馈多项式由 taps 决定。模块将伪随机值映射到 [WAIT_MIN_MS, WAIT_MAX_MS] 区间，并通过 req_random/random_valid 进行请求-应答握手。

仿真目标：
1. req_random 拉高后 random_valid 正确给出。
2. random_delay_ms 始终位于配置范围内。
3. 连续多次请求时输出值随时钟演进变化。

波形关注信号：req_random、random_valid、random_delay_ms、内部时钟。

### 3. 历史平均模块 score_history_avg

实现说明：
模块维护最近三次有效成绩，采用滚动窗口策略更新并计算平均值。仅当 push_valid=1 时写入样本，非法或无效结果不写入。

仿真目标：
1. 输入 1/2/3 组有效数据时平均值正确。
2. 第 4 组有效数据写入后，最旧数据被淘汰。
3. fail 对应样本不应写入历史记录。

建议激励：
依次输入三组有效值，再插入一组无效场景，检查 avg_valid 与 avg_time_ms 是否符合预期。

### 4. 控制器模块 reaction_controller

实现说明：
控制器使用有限状态机实现 IDLE、PREPARE、WAIT、REACT、FINISH、AVG、FAIL 之间的状态转移，并产生 req_random、counter_en、counter_clr、score_push_valid 等控制信号。

仿真目标：
1. 固定输入条件下状态转移路径正确。
2. WAIT 阶段提前按键进入 FAIL_EARLY。
3. REACT 阶段超时进入 FAIL_SLOW。
4. 合法反应时间下进入 FINISH 并产生 score_push_valid。

波形关注信号：state、next_state 相关触发、fail_code、reaction_time_ms、score_push_valid。

### 5. 外设模块

#### 5.1 按键去抖模块 button_debounce_pulse
实现说明：采用同步 + 稳定计数判定，输出单周期脉冲。

仿真目标：
1. 按键抖动期间不误触发。
2. 稳定按下后仅输出一次脉冲。
3. 松开过程不产生按下脉冲。

#### 5.2 数码管显示模块 seg7_display_driver
实现说明：按状态分类显示，WAIT/PREPARE 显示 ----，REACT 显示 1111，FINISH/AVG 显示数值，FAIL 显示 FAIL。

仿真目标：
1. 各状态段码输出符合分类条件。
2. 扫描状态下位选按顺序轮转。
3. 非扫描状态（----、1111）四位全开显示。

#### 5.3 蜂鸣器模块 buzzer_driver
实现说明：在状态跳变进入指定状态时触发短时鸣叫序列，而非持续鸣叫。

仿真目标：
1. 进入 REACT/FINISH/FAIL 时有短时有效输出。
2. 回到其他状态后输出拉低。
3. 连续状态跳变可重复触发提示音序列。

### 6. Vivado 中查看波形的操作步骤

1. 在 Vivado 工程中打开 Simulation Sources，添加对应 *_tb.v。
2. 设置仿真顶层为目标测试平台（如 ms_counter_service_tb）。
3. 运行 Run Simulation -> Run Behavioral Simulation。
4. 在 Objects/Scopes 中将关键信号加入 Wave 窗口。
5. 点击 Run For 或 Run All，观察波形是否满足本节目标。
6. 对每个模块至少截图一张“激励+关键响应”波形，用于报告插图。

### 7. 建议在报告中的写法

每个模块统一写三段：
1. 模块功能与实现思路。
2. 仿真激励设计（输入如何构造）。
3. 波形结果与结论（是否满足设计要求）。

这样可保持“实现-验证-结论”闭环，便于评分与答辩陈述。