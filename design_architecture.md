# 人体反应测试仪架构说明（自顶向下）

## 1. 模块总览

当前实现聚焦于与 IO 无关的 core 逻辑，模块划分如下：

- `reaction_core`：核心封装层，负责连接各子模块。
- `reaction_controller`：流程控制器，负责状态机转移和控制信号生成。
- `lfsr_random_service`：随机等待服务，提供随机等待时间。
- `score_history_avg`：历史成绩管理，维护最近三次有效成绩及平均值。
- `ms_counter_service`：毫秒计数服务，按 `counter_clr/counter_en` 控制。

该划分保证职责边界清晰，便于独立验证和后续扩展。

## 2. 状态机流程

状态机主流程为：

`IDLE -> PREPARE -> WAIT -> REACT -> FINISH/FAIL -> AVG -> PREPARE`

各状态语义：

- `IDLE`：等待 `start_pulse` 开始一轮。
- `PREPARE`：请求随机等待时间，收到 `random_valid` 后进入 `WAIT`。
- `WAIT`：等待随机延时结束；若提前按键则判定为早按失败。
- `REACT`：测量反应时间；按阈值判定为过短、过慢或有效。
- `FINISH`：展示有效结果，等待 `start_pulse` 进入 `AVG`。
- `FAIL`：展示失败结果，等待 `start_pulse` 进入 `AVG`。
- `AVG`：展示平均值，收到 `start_pulse` 后直接进入下一轮 `PREPARE`。

## 3. 随机服务握手

控制器与随机服务通过请求/响应握手解耦：

- 控制器输出 `req_random`：在 `PREPARE` 状态拉高，请求随机等待时间。
- 随机服务输出 `random_valid`：随机值准备好时拉高单拍。
- 随机服务输出 `random_delay_ms[12:0]`：随机等待时间（毫秒）。

约束规则：

- 仅在 `PREPARE && random_valid` 时采样 `random_delay_ms`。
- 进入 `WAIT` 后本轮 `wait_target_ms` 固定，不再被后续随机变化覆盖。

## 4. 历史成绩与平均值

历史统计逻辑与主状态机解耦：

- 控制器输出 `score_push_valid` 单拍作为写入命令。
- 控制器输出 `score_push_time_ms` 作为写入值。
- 历史模块输出 `hist_avg_valid` 与 `hist_avg_time_ms`。

约束规则：

- 仅有效反应成绩入历史。
- 失败结果不写入历史。
- `AVG` 状态显示历史平均值。

## 5. 关键时序规则

- 所有状态转移在 `clk` 上升沿发生。
- `counter_clr` 由 `state` 与 `next_state` 组合生成单拍：
  - `enter_wait = (state == PREPARE) && (next_state == WAIT)`
  - `enter_react = (state == WAIT) && (next_state == REACT)`
  - `counter_clr = enter_wait || enter_react`
- `counter_en` 在 `WAIT/REACT` 状态拉高。

该方式实现“进入计时阶段即清零”，避免清零与计数错拍。

## 6. 信号语义约定

### 6.1 reaction_time_ms

- `reaction_time_ms` 表示“本轮反应结果时间”，不是计数器实时当前值。
- 更新时机仅有三类：
  - 进入 `WAIT` 时清零；
  - `REACT` 收到 `react_pulse` 时锁存本轮测得值；
  - `REACT` 自然超时时锁存超时值。
- 其它状态保持上次结果。

### 6.2 fail_code

失败码定义如下：

- `FAIL_NONE`：无失败。
- `FAIL_EARLY`：`WAIT` 阶段提前按键。
- `FAIL_SHORT`：`REACT` 阶段按键时间小于 `REACT_MIN_MS`。
- `FAIL_SLOW`：`REACT` 阶段超时或按键时间大于 `REACT_MAX_MS`。

### 6.3 ready

- `ready=1` 表示流程处于可交互窗口：`IDLE`、`FINISH`、`FAIL`、`AVG`。
- `ready=0` 表示测试进行中：`PREPARE`、`WAIT`、`REACT`。

## 7. 输入约束与扩展说明

- `start_pulse`、`react_pulse`、`random_valid` 需为与 `clk` 同步的单拍信号。
- `ms_counter_service` 语义保持毫秒计数服务；若接入高频时钟，可在该模块内部加入分频/双计数实现，不影响 controller 接口语义。
- 后续若接入按键去抖与显示外设，建议在 core 外围封装，不破坏现有模块职责边界。
