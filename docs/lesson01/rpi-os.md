## 1.1: Introducing RPi OS, or bare-metal "Hello, World!"

我们将通过编写一个小的裸机“ Hello，World”应用程序开始我们的OS开发之旅。
我假设您已通过[Prerequisites](../Prerequisites.md)并已准备就绪。如果没有，现在是时候这样做了。

在我们前进之前，我想建立一个简单的命名约定。从README文件中，您可以看到整个教程分为几节课。每节课都由我称为“章节”的单独文件组成(现在，您正在阅读第1课，第1.1章)。一章进一步分为带有标题的“部分”。这种命名约定使我可以引用材料的不同部分。

我想让您注意的另一件事是，该教程包含许多源代码示例。我通常会通过提供完整的代码块来开始说明，然后逐行描述它。

### Project structure

每节课的源代码具有相同的结构。
您可以在[此处](https://github.com/s-matyukevich/raspberry-pi-os/tree/master/src/lesson01)找到本课程的源代码。

让我们简要描述此文件夹的主要组件：

1. **Makefile** 我们将使用[make](http://www.math.tau.ac.il/~danha/courses/software1/make-intro.html)实用程序来构建内核。 make的行为由Makefile配置，该文件包含有关如何编译和链接源代码的说明。
2. **build.sh or build.bat** 如果要使用Docker构建内核，则需要这些文件。您无需在笔记本电脑上安装make实用程序或编译器工具链。
3. **src** 此文件夹包含所有源代码。
4. **include** 所有的头文件都放在这里。

### Makefile

现在，让我们仔细看看项目Makefile。

make程序的主要目的是自动确定需要重新编译什么程序的片段，并发出命令来重新编译。
如果你不熟悉的Make和Makefile文件，我建议你阅读[这](http://opensourceforu.com/2012/06/gnu-make-in-detail-for-beginners/)的文章。

第一课中使用的Makefile可以在[here](https://github.com/s-matyukevich/raspberry-pi-os/blob/master/src/lesson01/Makefile)中找到。

下面列出了整个Makefile：

```
ARMGNU ?= aarch64-linux-gnu

COPS = -Wall -nostdlib -nostartfiles -ffreestanding -Iinclude -mgeneral-regs-only
ASMOPS = -Iinclude 

BUILD_DIR = build
SRC_DIR = src

all : kernel8.img

clean :
    rm -rf $(BUILD_DIR) *.img 

$(BUILD_DIR)/%_c.o: $(SRC_DIR)/%.c
    mkdir -p $(@D)
    $(ARMGNU)-gcc $(COPS) -MMD -c $< -o $@

$(BUILD_DIR)/%_s.o: $(SRC_DIR)/%.S
    $(ARMGNU)-gcc $(ASMOPS) -MMD -c $< -o $@

C_FILES = $(wildcard $(SRC_DIR)/*.c)
ASM_FILES = $(wildcard $(SRC_DIR)/*.S)
OBJ_FILES = $(C_FILES:$(SRC_DIR)/%.c=$(BUILD_DIR)/%_c.o)
OBJ_FILES += $(ASM_FILES:$(SRC_DIR)/%.S=$(BUILD_DIR)/%_s.o)

DEP_FILES = $(OBJ_FILES:%.o=%.d)
-include $(DEP_FILES)

kernel8.img: $(SRC_DIR)/linker.ld $(OBJ_FILES)
    $(ARMGNU)-ld -T $(SRC_DIR)/linker.ld -o $(BUILD_DIR)/kernel8.elf  $(OBJ_FILES)
    $(ARMGNU)-objcopy $(BUILD_DIR)/kernel8.elf -O binary kernel8.img
``` 

现在，让我们详细阐述该文件：

```
ARMGNU ?= aarch64-linux-gnu
```

Makefile以变量定义开头。 `ARMGNU` 是交叉编译器前缀。 我们需要 [交叉编译](https://en.wikipedia.org/wiki/Cross_compiler) 因为我们正在`x86`计算机上编译`arm64`体系结构的源代码。因此，我们将使用 `aarch64-linux-gnu-gcc` 代替 `gcc`。

```
COPS = -Wall -nostdlib -nostartfiles -ffreestanding -Iinclude -mgeneral-regs-only
ASMOPS = -Iinclude 
```

`COPS`和`ASMOPS`是在编译C和汇编代码时分别传递给编译器的选项。

这些选项的简短说明：

* **-Wall** 显示所有警告.
* **-nostdlib** 不使用C的标准库。 C标准库中的大多数函数调用最终都会与操作系统交互。我们正在编写一个裸机程序，并且我们没有任何底层操作系统，因此C标准库无论如何都无法为我们工作。
* **-nostartfiles** 不要使用标准的启动文件。启动文件负责设置初始堆栈指针，初始化静态数据以及跳转到主入口点。我们将自己完成所有这一切。
* **-ffreestanding** 独立环境(`ffreestanding`)是标准库不存在的环境, 并且程序启动入口不是主要的. 选项`-ffreestanding`指示编译器不需要定义标准函数具有其通常的意义。
* **-Iinclude** 在 `include` 文件夹中搜索头文件。
* **-mgeneral-regs-only**. 仅使用通用寄存器。 ARM处理器还具有[NEON](https://developer.arm.com/technologies/neon)寄存器。 我们不希望编译器使用它们，因为它们会增加额外的复杂性(例如，因为我们需要在上下文切换期间存储寄存器)。

```
BUILD_DIR = build
SRC_DIR = src
```

`SRC_DIR` 和 `BUILD_DIR` 是分别包含源代码和编译后Object文件的目录。

```
all : kernel8.img

clean :
    rm -rf $(BUILD_DIR) *.img 
```

接下来，我们定义make目标。 前两个参数非常简单: `all` 参数是默认目标, 每当输入不带任何参数的`make`时，它就会执行 (`make` 始终使用第一个参数作为默认参数). 这个参数只是将所有工作重定向到另一个参数， `kernel8.img`. 
`clean` 参数负责删除所有编译附加文件和已编译内核映像。

```
$(BUILD_DIR)/%_c.o: $(SRC_DIR)/%.c
    mkdir -p $(@D)
    $(ARMGNU)-gcc $(COPS) -MMD -c $< -o $@

$(BUILD_DIR)/%_s.o: $(SRC_DIR)/%.S
    $(ARMGNU)-gcc $(ASMOPS) -MMD -c $< -o $@
```

接下来的两个参数负责编译C和汇编文件. 例如，如果在 `src` 文件夹中 我们有 `foo.c` 和 `foo.S` 文件, 他们将会分别被链接为 `build/foo_c.o` 和 `build/foo_s.o`. `$<` 和 `$@` 在运行时将被替换成输入文件名和输出文件名 (`foo.c` and `foo_c.o`). 在编译C文件之前，我们还创建了一个build目录，以防该目录不存在。

```
C_FILES = $(wildcard $(SRC_DIR)/*.c)
ASM_FILES = $(wildcard $(SRC_DIR)/*.S)
OBJ_FILES = $(C_FILES:$(SRC_DIR)/%.c=$(BUILD_DIR)/%_c.o)
OBJ_FILES += $(ASM_FILES:$(SRC_DIR)/%.S=$(BUILD_DIR)/%_s.o)
```

在这里，我们正在构建一个由C和汇编源文件的串联创建的目标文件（`OBJ_FILES`）的数组。

```
DEP_FILES = $(OBJ_FILES:%.o=%.d)
-include $(DEP_FILES)
```

接下来的两行有些棘手。 如果看一下我们如何为C和汇编源文件定义编译目标，您会注意到我们使用了-MMD参数。这个参数指示`gcc`编译器为每个生成的目标文件创建一个依赖文件。

依赖性文件定义了特定源文件的所有依赖性。 这些依赖项通常包含所有包含的标头的列表。 我们需要包括所有生成的依赖文件，以便在头更改时知道要重新编译的内容。

```
$(ARMGNU)-ld -T $(SRC_DIR)/linker.ld -o kernel8.elf  $(OBJ_FILES)
``` 

我们使用 `OBJ_FILES` 数组构建 `kernel8.elf` 文件.

我们使用链接描述文件`src /linker.ld`定义生成的可执行映像的基本布局。 (我们将在下一部分中讨论链接器脚本).

```
$(ARMGNU)-objcopy kernel8.elf -O binary kernel8.img
```

`kernel8.elf` 遵循 [ELF](https://en.wikipedia.org/wiki/Executable_and_Linkable_Format) 格式. 问题是ELF文件设计为由操作系统执行. 要编写裸机程序，我们需要从ELF文件中提取所有可执行文件和数据段，然后将它们放入 `kernel8.img` 中. 尾部的 `8` 表示ARMv8，它是64位体系结构. 该文件名告诉固件将处理器引导到64位模式。
您也可以使用`config.txt`文件中的`arm_control = 0x200`标志以64位模式引导CPU。 RPi OS以前使用此方法，您仍然可以在一些练习答案中找到它。 然而, 尚未记录`arm_control`标志，最好使用`kernel8.img`命名约定。

### The linker script

链接描述文件的主要目的是描述如何将输入目标文件（`_c.o`和`_s.o`）中的段映射到输出文件（`.elf`）中。 可以找到有关链接描述文件的更多信息在[这](https://sourceware.org/binutils/docs/ld/Scripts.html#Scripts). 

现在让我们看一下RPi OS链接器脚本:

```
SECTIONS
{
    .text.boot : { *(.text.boot) }
    .text :  { *(.text) }
    .rodata : { *(.rodata) }
    .data : { *(.data) }
    . = ALIGN(0x8);
    bss_begin = .;
    .bss : { *(.bss*) } 
    bss_end = .;
}
``` 

启动后，Raspberry Pi将`kernel8.img`加载到内存中，并从文件开头开始执行. 这就是为什么`.text.boot`部分必须放在第一位的原因; 我们将把操作系统启动代码放入本节中。 
`.text`, `.rodata`, 和 `.data` 部分包含内核编译的指令, 只读数据, 和 一般数据––这里没有什么特别的补充。
`.bss`部分包含应初始化为 `0` 的数据. 
    通过将此类数据放在单独的部分中，编译器可以在ELF二进制文件中节省一些空间––只有部分大小存储在ELF标头中, 但本节本身被省略.
    将`img`加载到内存后, 我们必须将`.bss`部分初始化为`0`; 这就是为什么我们需要记录本节的开始和结束 (因此`bss_begin`和`bss_end`符号) 和 对齐该节，使其以8的倍数开头的地址开始. 如果该部分未对齐, 使用`str`指令在`bss`节的开头存储`0`会更加困难 因为`str`指令只能与8字节对齐的地址一起使用。

### Booting the kernel

现在是时候看看[boot.S]（https://github.com/s-matyukevich/raspberry-pi-os/blob/master/src/lesson01/src/boot.S）文件了。

此文件包含内核启动代码：

```
#include "mm.h"

.section ".text.boot"

.globl _start
_start:
    mrs    x0, mpidr_el1        
    and    x0, x0,#0xFF        // Check processor id
    cbz    x0, master        // Hang for all non-primary CPU
    b    proc_hang

proc_hang: 
    b proc_hang

master:
    adr    x0, bss_begin
    adr    x1, bss_end
    sub    x1, x1, x0
    bl     memzero

    mov    sp, #LOW_MEMORY
    bl    kernel_main
```

让我们详细查看该文件：
```
.section ".text.boot"
```

首先，指定定义在`boot.S`中的所有内容都应在`.text.boot`部分中。 先前, 我们已经看到，该节通过链接描述文件放置在内核映像的开头. 

因此，当内核启动时，执行从`start`函数开始：

```
.globl _start
_start:
    mrs    x0, mpidr_el1        
    and    x0, x0,#0xFF        // Check processor id
    cbz    x0, master        // Hang for all non-primary CPU
    b    proc_hang
```

这个函数做的第一件事就是检查 processor id 。Raspberry Pi 3 有四个核心,设备开启之后, 每个核心处理相同的代码. 然而，我不们不需要四个核心都工作; 我们希望只是用第一个核心并且将其他核心放到尾部的循环中. 这就是 `_start` 函数的责任. 从[mpidr_el1](http://infocenter.arm.com/help/index.jsp?topic=/com.arm.doc.ddi0500g/BABHBJCI.html) system register. 获取 processor ID
如果当前 process ID 是 0, 之后执行跳转到 `master` 函数:

```
master:
    adr    x0, bss_begin
    adr    x1, bss_end
    sub    x1, x1, x0
    bl     memzero
```

在这里，我们通过调用`memzero`来清理`.bss`部分。我们稍后将定义此功能. 在ARMv8架构中, 按照惯例, 前七个参数通过寄存器x0–x6传递给调用的函数. `memzero` 函数仅接受两个参数: 起始地址 (`bss_begin`) 以及需要清理的部分的大小 (`bss_end - bss_begin`).

```
    mov    sp, #LOW_MEMORY
    bl    kernel_main
```

清理`.bss`部分后，我们初始化堆栈指针并将执行传递给`kernel_main`函数。 
Raspberry Pi在地址0加载内核; 这就是为什么可以将初始堆栈指针设置到足够高的任何位置的原因，以便当堆栈映像变得足够大时，堆栈不会覆盖内核映像. `LOW_MEMORY` 在 [mm.h](https://github.com/s-matyukevich/raspberry-pi-os/blob/master/src/lesson01/include/mm.h) 中定义等于4MB. 我们的内核堆栈不会变得很大，并且img本身很小，因此`4MB`对我们来说绰绰有余. 

对于那些不熟悉`ARM`汇编器语法的人，让我快速总结一下我们已经使用的指令：

* [**mrs**](http://www.keil.com/support/man/docs/armasm/armasm_dom1361289881374.htm) 将值从系统寄存器加载到通用寄存器之一（x0–x30）
* [**and**](http://www.keil.com/support/man/docs/armasm/armasm_dom1361289863017.htm) 执行逻辑与运算。我们使用此命令从 `mpidr_el1` 寄存器中将获得的值剥离最后一个字节。
* [**cbz**](http://www.keil.com/support/man/docs/armasm/armasm_dom1361289867296.htm) 比较之前执行的操作的结果，并且如果比较结果为真跳转 (或者 `branch` 在ARM术语中) 到提供的标签.
* [**b**](http://www.keil.com/support/man/docs/armasm/armasm_dom1361289863797.htm) 对某些标签执行无条件转移（`branch`）。
* [**adr**](http://www.keil.com/support/man/docs/armasm/armasm_dom1361289862147.htm) 将标签的相对地址加载到目标寄存器中。 在这种情况下，我们需要指向`.bss`区域开始和结束的指针。
* [**sub**](http://www.keil.com/support/man/docs/armasm/armasm_dom1361289908389.htm) 从两个寄存器取值互减。
* [**bl**](http://www.keil.com/support/man/docs/armasm/armasm_dom1361289865686.htm) "Branch with a link": 执行无条件分支并将返回地址存储在x30中(链接寄存器). 子程序完成后, 使用`ret`指令跳回到调用人地址.
* [**mov**](http://www.keil.com/support/man/docs/armasm/armasm_dom1361289878994.htm) 在寄存器之间移动一个值 或者 从常量移动到寄存器.

[这](http://infocenter.arm.com/help/index.jsp?topic=/com.arm.doc.den0024a/index.html) 是ARMv8-A开发人员指南. 如果你不熟悉ARM ISA，这是一个很好的资源. [这页](http://infocenter.arm.com/help/index.jsp?topic=/com.arm.doc.den0024a/ch09s01s01.html) 特别概述了ABI中的寄存器使用约定。

### The `kernel_main` function

我们已经看到引导代码最终将控制权传递给了`kernel_main`函数。

让我们看一下：

```
#include "mini_uart.h"

void kernel_main(void)
{
    uart_init();
    uart_send_string("Hello, world!\r\n");

    while (1) {
        uart_send(uart_recv());
    }
}

```

此功能是内核中最简单的功能之一. 它与 `Mini UART` 设备 打印到屏幕并阅读用户输入. 内核只是打印 `Hello, world!` 然后进入无限循环，此循环从用户读取字符并将其发送回屏幕.

### Raspberry Pi devices 

现在，我们将深入研究Raspberry Pi的特定功能. 开始之前, 我建议您下载[BCM2837 ARM Peripherals manual](https://github.com/raspberrypi/documentation/files/1888662/BCM2837-ARM-Peripherals.-.Revised.-.V2-1.pdf). `BCM2837` 是 Raspberry Pi 3 Model B 和 B+ 使用的板. 在我们讨论中, 我还将提到 `BCM2835` 和 `BCM2836` - 这些是旧版Raspberry Pi中使用的板子的名称.  

在我们进行实施细节之前, 我想分享一些有关如何使用内存映射设备的基本概念. BCM2837 是一个简单的 [SOC (System on a chip 片选系统)](https://en.wikipedia.org/wiki/System_on_a_chip) 板. 在这样的板上, 通过存储器映射寄存器执行对所有设备的访问. Raspberry Pi 3 保留地址上方的 `0x3F000000` 内存用于设备. 去启用或者配置一个特定设备, 你需要写入到设备的一个寄存器中一些数据. 一个设备的寄存器中只在内存中占据32位.  `BCM2837 ARM Peripherals` 手册中描述了寄存器每一位的作用. 在手册和周围的文件中看一下 1.2.3节 ARM 的物理地址和有关更多为什么我们用` 0x3F000000` 作为基地址的背景信息(即使 `0x7E000000` 在整个手册中被使用).

从`kernel_main`函数, 您可以猜测我们将使用Mini UART器件. UART代表 [Universal asynchronous receiver-transmitter 通用异步收发器](https://en.wikipedia.org/wiki/Universal_asynchronous_receiver-transmitter). 该设备能够将存储在其存储器映射寄存器之一中的值转换为高电压和低电压序列。 该序列通过 `TTL转串口电缆` 传递到您的计算机，并由终端仿真器解释. 我们将使用Mini UART来促进与Raspberry Pi的通信. 如果要查看Mini UART寄存器的规范，请转到`BCM2837 ARM Peripherals`手册的第8页。

Raspberry Pi具有两个UART：迷你UART和PL011 UART。在本教程中，我们将仅使用第一个教程，因为它更简单。但是，有一个可选的[exercise]（https://github.com/s-matyukevich/raspberry-pi-os/blob/master/docs/lesson01/exercises.md）显示了如何使用PL011 UART.

如果您想了解有关Raspberry Pi UART的更多信息并了解它们之间的区别，可以参考[官方文档]（https://www.raspberrypi.org/documentation/configuration/uart.md）。

您需要熟悉的另一个设备是GPIO[General-purpose input/output 通用输入/输出](https://en.wikipedia.org/wiki/General-purpose_input/output). GPIO负责控制GPIO引脚. 您应该能够在下图中轻松识别它们：

![Raspberry Pi GPIO pins](../../images/gpio-pins.jpg)

GPIO可用于配置不同GPIO引脚的行为。 例如，为了能够使用Mini UART, 我们需要激活引脚14和15并将其设置为使用此设备. 

下图说明了如何将数字分配给GPIO引脚：

![Raspberry Pi GPIO pin numbers](../../images/gpio-numbers.png)

### Mini UART initialization

现在让我们看一下如何初始化迷你UART. 

该代码在[mini_uart.c](https://github.com/s-matyukevich/raspberry-pi-os/blob/master/src/lesson01/src/mini_uart.c):

```c
void uart_init ( void )
{
    unsigned int selector;

    selector = get32(GPFSEL1);
    selector &= ~(7<<12);                   // clean gpio14
    selector |= 2<<12;                      // set alt5 for gpio14
    selector &= ~(7<<15);                   // clean gpio15
    selector |= 2<<15;                      // set alt5 for gpio 15
    put32(GPFSEL1,selector);

    put32(GPPUD,0);
    delay(150);
    put32(GPPUDCLK0,(1<<14)|(1<<15));
    delay(150);
    put32(GPPUDCLK0,0);

    put32(AUX_ENABLES,1);                   //Enable mini uart (this also enables access to it registers)
    put32(AUX_MU_CNTL_REG,0);               //Disable auto flow control and disable receiver and transmitter (for now)
    put32(AUX_MU_IER_REG,0);                //Disable receive and transmit interrupts
    put32(AUX_MU_LCR_REG,3);                //Enable 8 bit mode
    put32(AUX_MU_MCR_REG,0);                //Set RTS line to be always high
    put32(AUX_MU_BAUD_REG,270);             //Set baud rate to 115200

    put32(AUX_MU_CNTL_REG,3);               //Finally, enable transmitter and receiver
}
``` 

在这里，我们使用两个函数`put32`和`get32`。 这些功能非常简单; 它们允许我们在32位寄存器中读写数据。 您可以看看它们是如何实现 [utils.S](https://github.com/s-matyukevich/raspberry-pi-os/blob/master/src/lesson01/src/utils.S). `uart_init` 是本课中最复杂，最重要的功能之一，我们将在接下来的三个部分中继续进行研究.

#### GPIO alternative function selection 

首先，我们需要激活GPIO引脚. 大多数引脚可以与不同的设备一起使用, 所以在使用特定的针之前, 我们需要选择引脚的`替代功能(alternative function)`. 
`替代功能`只是可以为每个引脚设置的0到5之间的数字，并配置将哪个设备连接到该引脚. 

您可以在下图中看到所有可用的GPIO替代功能的列表 (该图像取自《 BCM2837 ARM Peripherals》手册的第102页):

![Raspberry Pi GPIO alternative functions](../../images/alt.png?raw=true)

在这里您可以看到引脚14和15具有TXD1和RXD1替代功能. 这意味着如果我们为引脚14和15选择替代功能编号5，它们将分别用作Mini UART发送数据引脚和Mini UART接收数据引脚。 `GPFSEL1` 寄存器用于控制引脚10-19的替代功能. 

这些寄存器中所有位的含义如下表所示 (page 92 of `BCM2837 ARM Peripherals` manual):

![Raspberry Pi GPIO function selector](../../images/gpfsel1.png?raw=true)

因此，现在您知道了您需要了解的以下几行代码，

这些代码用于配置GPIO引脚14和15以与Mini UART器件配合使用：

```
    unsigned int selector;

    selector = get32(GPFSEL1);
    selector &= ~(7<<12);                   // clean gpio14
    selector |= 2<<12;                      // set alt5 for gpio14
    selector &= ~(7<<15);                   // clean gpio15
    selector |= 2<<15;                      // set alt5 for gpio 15
    put32(GPFSEL1,selector);
```

#### GPIO pull-up/down 

当您使用Raspberry Pi GPIO引脚时，经常会遇到诸如上拉/下拉等术语. 这些概念的详细解释在 [这篇](https://grantwinney.com/using-pullup-and-pulldown-resistors-on-the-raspberry-pi/) 文章中. 

对于那些懒于阅读整篇文章的人，我将简要解释上拉/下拉概念。

如果您使用特定的引脚作为输入，并且不将该引脚连接任何东西，则将无法识别该引脚的值是1还是0。 实际上，设备将报告为随机值。 上拉/下拉机制可解决此问题。 如果将引脚设置为上拉状态，但没有任何连接，则引脚将始终报告 `1`（对于下拉状态，该值始终为0）。 就我们而言, 我们既不需要上拉状态也不需要下拉状态, 因为14和15引脚将一直保持连接状态. 即使重新启动后，引脚状态也会保留，因此在使用任何引脚之前，我们总是必须初始化其状态。 有三种可用状态: 上拉，下拉和两者都不显示（以删除当前的上拉或下拉状态）, 我们需要第三个.

Switching between pin states is not a very simple procedure because it requires physically toggling a switch on the electric circuit. This process involves the `GPPUD` and `GPPUDCLK` registers and is described on page 101 of the `BCM2837 ARM Peripherals` manual. I copied the description here:

```
The GPIO Pull-up/down Clock Registers control the actuation of internal pull-downs on
the respective GPIO pins. These registers must be used in conjunction with the GPPUD
register to effect GPIO Pull-up/down changes. The following sequence of events is
required:
1. Write to GPPUD to set the required control signal (i.e. Pull-up or Pull-Down or neither
to remove the current Pull-up/down)
2. Wait 150 cycles – this provides the required set-up time for the control signal
3. Write to GPPUDCLK0/1 to clock the control signal into the GPIO pads you wish to
modify – NOTE only the pads which receive a clock will be modified, all others will
retain their previous state.
4. Wait 150 cycles – this provides the required hold time for the control signal
5. Write to GPPUD to remove the control signal
6. Write to GPPUDCLK0/1 to remove the clock
``` 

This procedure describes how we can remove both the pull-up and pull-down states from a pin, which is what we are doing for pins 14 and 15 in the following code:

```
    put32(GPPUD,0);
    delay(150);
    put32(GPPUDCLK0,(1<<14)|(1<<15));
    delay(150);
    put32(GPPUDCLK0,0);
```

#### Initializing the Mini UART

Now our Mini UART is connected to the GPIO pins, and the pins are configured. The rest of the `uart_init` function is dedicated to Mini UART initialization. 

```
    put32(AUX_ENABLES,1);                   //Enable mini uart (this also enables access to its registers)
    put32(AUX_MU_CNTL_REG,0);               //Disable auto flow control and disable receiver and transmitter (for now)
    put32(AUX_MU_IER_REG,0);                //Disable receive and transmit interrupts
    put32(AUX_MU_LCR_REG,3);                //Enable 8 bit mode
    put32(AUX_MU_MCR_REG,0);                //Set RTS line to be always high
    put32(AUX_MU_BAUD_REG,270);             //Set baud rate to 115200
    put32(AUX_MU_IIR_REG,6);                //Clear FIFO

    put32(AUX_MU_CNTL_REG,3);               //Finally, enable transmitter and receiver
```
Let's examine this code snippet line by line. 

```
    put32(AUX_ENABLES,1);                   //Enable mini uart (this also enables access to its registers)
```
This line enables the Mini UART. We must do this in the beginning, because this also enables access to all the other Mini UART registers.

```
    put32(AUX_MU_CNTL_REG,0);               //Disable auto flow control and disable receiver and transmitter (for now)
```
Here we disable the receiver and transmitter before the configuration is finished. We also permanently disable auto-flow control because it requires us to use additional GPIO pins, and the TTL-to-serial cable doesn't support it. For more information about auto-flow control, you can refer to [this](http://www.deater.net/weave/vmwprod/hardware/pi-rts/) article.

```
    put32(AUX_MU_IER_REG,0);                //Disable receive and transmit interrupts
```
It is possible to configure the Mini UART to generate a processor interrupt each time new data is available. We are going to start working with interrupts in lesson 3, so for now, we will just disable this feature.

```
    put32(AUX_MU_LCR_REG,3);                //Enable 8 bit mode
```
Mini UART can support either 7- or 8-bit operations. This is because an ASCII character is 7 bits for the standard set and 8 bits for the extended. We are going to use 8-bit mode. 

```
    put32(AUX_MU_MCR_REG,0);                //Set RTS line to be always high
```
The RTS line is used in the flow control and we don't need it. Set it to be high all the time.
```
    put32(AUX_MU_BAUD_REG,270);             //Set baud rate to 115200
```
The baud rate is the rate at which information is transferred in a communication channel. “115200 baud” means that the serial port is capable of transferring a maximum of 115200 bits per second. The baud rate of your Raspberry Pi mini UART device should be the same as the baud rate in your terminal emulator. 
The Mini UART calculates baud rate according to the following equation:
```
baudrate = system_clock_freq / (8 * ( baudrate_reg + 1 )) 
```
The `system_clock_freq` is 250 MHz, so we can easily calculate the value of `baudrate_reg` as 270.

``` 
    put32(AUX_MU_CNTL_REG,3);               //Finally, enable transmitter and receiver
```
After this line is executed, the Mini UART is ready for work!

### Sending data using the Mini UART

After the Mini UART is ready, we can try to use it to send and receive some data. To do this, we can use the following two functions:

```
void uart_send ( char c )
{
    while(1) {
        if(get32(AUX_MU_LSR_REG)&0x20) 
            break;
    }
    put32(AUX_MU_IO_REG,c);
}

char uart_recv ( void )
{
    while(1) {
        if(get32(AUX_MU_LSR_REG)&0x01) 
            break;
    }
    return(get32(AUX_MU_IO_REG)&0xFF);
}
```

Both of the functions start with an infinite loop, the purpose of which is to verify whether the device is ready to transmit or receive data. We are using  the `AUX_MU_LSR_REG` register to do this. Bit zero, if set to 1, indicates that the data is ready; this means that we can read from the UART. Bit five, if set to 1, tells us that the transmitter is empty, meaning that we can write to the UART.
Next, we use `AUX_MU_IO_REG` to either store the value of the transmitted character or read the value of the received character.

We also have a very simple function that is capable of sending strings instead of characters:

```
void uart_send_string(char* str)
{
    for (int i = 0; str[i] != '\0'; i ++) {
        uart_send((char)str[i]);
    }
}
```
This function just iterates over all characters in a string and sends them one by one. 

### Raspberry Pi config

The Raspberry Pi startup sequence is the following (simplified):

1. The device is powered on.
1. The GPU starts up and reads the `config.txt` file from the boot partition. This file contains some configuration parameters that the GPU uses to further adjust the startup sequence.
1. `kernel8.img` is loaded into memory and executed.

To be able to run our simple OS, the `config.txt` file should be the following:

```
kernel_old=1
disable_commandline_tags=1
```
* `kernel_old=1` specifies that the kernel image should be loaded at address 0.
* `disable_commandline_tags` instructs the GPU to not pass any command line arguments to the booted image.


### Testing the kernel

Now that we have gone through all of the source code, it is time to see it work. To build and test the kernel you need to  do the following:

1. Execute `./build.sh` or `./build.bat` from [src/lesson01](https://github.com/s-matyukevich/raspberry-pi-os/tree/master/src/lesson01) in order to build the kernel. 
1. Copy the generated `kernel8.img` file to the `boot` partition of your Raspberry Pi flash card and delete `kernel7.img`. Make sure you left all other files in the boot partition untouched (see [this](https://github.com/s-matyukevich/raspberry-pi-os/issues/43) issue for details)
1. Modify the `config.txt` file as described in the previous section.
1. Connect the USB-to-TTL serial cable as described in the [Prerequisites](../Prerequisites.md).
1. Power on your Raspberry Pi.
1. Open your terminal emulator. You should be able to see the `Hello, world!` message there.

Note that the sequence of steps described above asumes that you have Raspbian installed on your SD card. It is also posible to run the RPi OS using an empty SD card.

1. Prepare your SD card:
    * Use an MBR partition table
    * Format the boot partition as FAT32
    > The card should be formatted exactly in the same way as it is required to install Raspbian. Check `HOW TO FORMAT AN SD CARD AS FAT` section in the [official documenation](https://www.raspberrypi.org/documentation/installation/noobs.md) for more information.
1. Copy the following files to the card:
    * [bootcode.bin](https://github.com/raspberrypi/firmware/blob/master/boot/bootcode.bin) This is the GPU bootloader, it contains the GPU code to start the GPU and load the GPU firmware. 
    * [start.elf](https://github.com/raspberrypi/firmware/blob/master/boot/start.elf) This is the GPU firmware. It reads `config.txt` and enables the GPU to load and run ARM specific user code from `kernel8.img`
1. Copy `kernel8.img` and `config.txt` files. 
1. Connect the USB-to-TTL serial cable.
1. Power on your Raspberry Pi.
1. Use your terminal emulator to connect to the RPi OS. 

Unfortunately, all Raspberry Pi firmware files are closed-sourced and undocumented. For more information about the Raspberry Pi startup sequence, you can refer to some unofficial sources, like [this](https://raspberrypi.stackexchange.com/questions/10442/what-is-the-boot-sequence) StackExchange question or [this](https://github.com/DieterReuter/workshop-raspberrypi-64bit-os/blob/master/part1-bootloader.md) Github repository.

##### Previous Page

[Prerequisites](../../docs/Prerequisites.md)

##### Next Page

1.2 [Kernel Initialization: Linux project structure](../../docs/lesson01/linux/project-structure.md)
