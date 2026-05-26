"""
生成机载X波段SAR回波仿真与RD成像算法课程报告 (Word格式)
参考 reference.pdf 的报告结构
字体规范：汉字宋体，英文Times New Roman，正文小四(12pt)
标题逐级加大加粗，目录添加超链接
公式使用OMML公式编辑器，右侧加编号
"""
from docx import Document
from docx.shared import Pt, Cm, RGBColor, Emu
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml.ns import qn, nsdecls
from docx.oxml import parse_xml
from lxml import etree
import os

# OMML命名空间
OMML_NS = 'http://schemas.openxmlformats.org/officeDocument/2006/math'
nsmap = {'m': OMML_NS, 'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}

equation_counter = [0]  # 用列表包装以便在函数内修改


def make_omml_paragraph(doc, latex_like_str, eq_num=None):
    """创建包含OMML公式的段落，右侧带编号"""
    equation_counter[0] += 1
    num = eq_num if eq_num else equation_counter[0]

    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER

    # 构建OMML公式XML
    omath_xml = build_omml(latex_like_str)
    p._p.append(omath_xml)

    # 添加编号（右对齐用tab）
    run = p.add_run(f'\t\t({num})')
    run.font.name = 'Times New Roman'
    run.element.rPr.rFonts.set(qn('w:eastAsia'), '宋体')
    run.font.size = Pt(12)
    return p



def build_omml(text):
    """将简化公式文本转换为OMML XML元素"""
    # 使用oMathPara包裹oMath
    omath_para = etree.SubElement(
        etree.Element('{%s}oMathPara' % OMML_NS), '{%s}oMath' % OMML_NS
    )
    omath = etree.SubElement(
        parse_xml(f'<m:oMathPara xmlns:m="{OMML_NS}"/>'),
        '{%s}oMath' % OMML_NS
    )
    # 添加run
    r = etree.SubElement(omath, '{%s}r' % OMML_NS)
    rpr = etree.SubElement(r, '{%s}rPr' % OMML_NS)
    sty = etree.SubElement(rpr, '{%s}sty' % OMML_NS)
    sty.set('{%s}val' % OMML_NS, 'p')  # plain style
    t = etree.SubElement(r, '{%s}t' % OMML_NS)
    t.text = text
    return omath.getparent()


def add_bookmark(paragraph, bookmark_name):
    """给段落添加书签"""
    run = paragraph.runs[0] if paragraph.runs else paragraph.add_run('')
    tag = run._r
    start = parse_xml(
        f'<w:bookmarkStart {nsdecls("w")} w:id="0" w:name="{bookmark_name}"/>'
    )
    end = parse_xml(
        f'<w:bookmarkEnd {nsdecls("w")} w:id="0"/>'
    )
    tag.addprevious(start)
    tag.addnext(end)


def add_hyperlink_to_bookmark(paragraph, bookmark_name, text):
    """在段落中添加指向书签的超链接"""
    hyperlink = parse_xml(
        f'<w:hyperlink {nsdecls("w")} w:anchor="{bookmark_name}">'
        f'<w:r><w:rPr><w:rStyle w:val="Hyperlink"/>'
        f'<w:color w:val="0000FF"/><w:u w:val="single"/>'
        f'<w:rFonts w:eastAsia="宋体" w:ascii="Times New Roman" w:hAnsi="Times New Roman"/>'
        f'<w:sz w:val="24"/></w:rPr>'
        f'<w:t>{text}</w:t></w:r></w:hyperlink>'
    )
    paragraph._p.append(hyperlink)



# ============ 开始生成文档 ============
doc = Document()

# 设置默认样式
style = doc.styles['Normal']
style.font.size = Pt(12)
style.font.name = 'Times New Roman'
style.element.rPr.rFonts.set(qn('w:eastAsia'), '宋体')
style.paragraph_format.line_spacing = 1.5

# Heading 1: 二号(22pt) 加粗
h1_style = doc.styles['Heading 1']
h1_style.font.size = Pt(22)
h1_style.font.bold = True
h1_style.font.name = 'Times New Roman'
h1_style.element.rPr.rFonts.set(qn('w:eastAsia'), '宋体')
h1_style.font.color.rgb = RGBColor(0, 0, 0)

# Heading 2: 三号(16pt) 加粗
h2_style = doc.styles['Heading 2']
h2_style.font.size = Pt(16)
h2_style.font.bold = True
h2_style.font.name = 'Times New Roman'
h2_style.element.rPr.rFonts.set(qn('w:eastAsia'), '宋体')
h2_style.font.color.rgb = RGBColor(0, 0, 0)

# ============ 封面 ============
for _ in range(3):
    doc.add_paragraph()
title = doc.add_paragraph()
title.alignment = WD_ALIGN_PARAGRAPH.CENTER
run = title.add_run('《雷达探测与成像》课程大作业')
run.font.size = Pt(26)
run.bold = True
run.font.name = 'Times New Roman'
run.element.rPr.rFonts.set(qn('w:eastAsia'), '宋体')
doc.add_paragraph()
doc.add_paragraph()
for label, value in [('学    院','电子工程学院'),('班    级',''),
                     ('学    号',''),('姓    名',''),('导    师','')]:
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = p.add_run(f'{label}     {value}')
    run.font.size = Pt(14)
    run.font.name = 'Times New Roman'
    run.element.rPr.rFonts.set(qn('w:eastAsia'), '宋体')
doc.add_paragraph()
date_p = doc.add_paragraph()
date_p.alignment = WD_ALIGN_PARAGRAPH.CENTER
run = date_p.add_run('2025 年  6 月')
run.font.size = Pt(14)
doc.add_page_break()


# ============ 目录 ============
toc_title = doc.add_heading('目录', level=1)
add_bookmark(toc_title, 'toc_page')
for bm, txt in [('bm_ch1','一、RD算法介绍'),('bm_ch2','二、RD算法原理'),
                 ('bm_ch3','三、系统参数设计'),('bm_ch4','四、RD算法仿真结果'),
                 ('bm_ch5','五、心得体会'),('bm_appendix','附录：完整MATLAB代码')]:
    p = doc.add_paragraph()
    add_hyperlink_to_bookmark(p, bm, txt)
doc.add_page_break()

# ============ 一、RD算法介绍 ============
h = doc.add_heading('一、RD算法介绍', level=1)
add_bookmark(h, 'bm_ch1')
doc.add_paragraph(
    '距离多普勒算法（RDA）是在1976年至1978年为处理SEASAT SAR数据而提出的，'
    '该算法于1978年处理出第一幅机载SAR数字图像。RDA至今仍在广泛使用，'
    '它通过距离和方位上的频域操作，达到了高效的模块化处理要求，同时又具有了一维操作的简便性。'
    '该算法根据距离和方位上的大尺度时间差异，在两个一维操作之间使用距离徙动校正（RCMC），'
    '对距离和方位进行了近似的分离处理。')
doc.add_paragraph(
    '由于RCMC是在距离时域-方位频域中实现的，所以也可以进行高效的模块化处理。'
    '因为方位频率等同于多普勒频率，所以该处理域又称为"距离多普勒"域。'
    'RCMC的"距离多普勒"域实现是RDA与其他算法的主要区别点，因而称其为距离多普勒算法。')
doc.add_paragraph(
    '距离相同而方位不同的点目标能量变换到方位频域后，其位置重合，'
    '因此频域中的单一目标轨迹校正等效于同一最近斜距处的一组目标轨迹的校正。'
    '这是算法的关键，使RCMC能在距离多普勒域高效地实现。')
doc.add_paragraph(
    '为了提高处理效率，所有的匹配滤波器卷积都通过频域相乘实现，'
    '匹配滤波及RCMC都与距离可变参数有关。RDA区别于其他频域算法的另一主要特点是'
    '较易适应距离向参数的变化。所有运算都针对一维数据进行，从而达到了处理的简便和高效。')
doc.add_page_break()


# ============ 二、RD算法原理 ============
h = doc.add_heading('二、RD算法原理', level=1)
add_bookmark(h, 'bm_ch2')
doc.add_paragraph('RD算法的处理流程如下：')
doc.add_paragraph('1) 距离FFT后进行距离向匹配滤波，再利用距离IFFT完成距离压缩。')
doc.add_paragraph('2) 通过方位FFT将数据变换至距离多普勒域。')
doc.add_paragraph('3) 在距离多普勒域进行RCMC，该域中同一距离上的目标轨迹相互重合。')
doc.add_paragraph('4) 通过每一距离门上的频域匹配滤波实现方位压缩。')
doc.add_paragraph('5) 最后通过方位IFFT将数据变换回时域，得到压缩后的复图像。')
doc.add_paragraph()

doc.add_heading('步骤1：原始数据（回波信号模型）', level=2)
doc.add_paragraph('设第i个点目标位于(xi, yi, 0)，雷达位置为(0, V·η, H)，瞬时斜距为：')
make_omml_paragraph(doc, 'R_i(η) = √(x_i² + (Vη - y_i)² + H²)', eq_num=1)
doc.add_paragraph('点目标的基带回波信号为：')
make_omml_paragraph(doc,
    's(τ,η) = A·w_r(τ-2R(η)/c)·w_a(η-η_c)·exp{-j4πf₀R(η)/c}·exp{jπK_r(τ-2R(η)/c)²}',
    eq_num=2)
doc.add_paragraph('其中τ为距离向快时间，η为方位向慢时间，Kr为调频斜率。')

doc.add_heading('步骤2：距离压缩', level=2)
doc.add_paragraph('构建距离向匹配滤波器：')
make_omml_paragraph(doc, 'H(f_τ) = exp{jπf_τ²/K_r}', eq_num=3)
doc.add_paragraph('将数据与滤波器频域相乘后IFFT，完成距离脉冲压缩。距离分辨率为：')
make_omml_paragraph(doc, 'ρ_r = c/(2B) = 3×10⁸/(2×300×10⁶) = 0.5 m', eq_num=4)


doc.add_heading('步骤3：方位FFT', level=2)
doc.add_paragraph('方位向调频率近似为：')
make_omml_paragraph(doc, 'K_a ≈ 2V²/(λ·R₀)', eq_num=5)
doc.add_paragraph('方位FFT后数据变换至距离多普勒域，包络中的距离走动（RCM）表示为：')
make_omml_paragraph(doc, 'R_rd(f_η) ≈ R₀ + λ²·R₀·f_η²/(8V²)', eq_num=6)

doc.add_heading('步骤4：距离徙动校正（RCMC）', level=2)
doc.add_paragraph('需要校正的距离弯曲量为：')
make_omml_paragraph(doc, 'ΔR(f_η) = λ²·R₀·f_η²/(8V²)', eq_num=7)
doc.add_paragraph(
    '在距离多普勒域中，计算每个(R₀, f_η)点对应的ΔR，采用8点Sinc插值核'
    '对距离向进行重采样对齐，完成距离走动校正。')

doc.add_heading('步骤5：方位压缩', level=2)
doc.add_paragraph('方位向匹配滤波器系数为：')
make_omml_paragraph(doc, 'H_az(f_η) = exp{-jπf_η²/K_a}', eq_num=8)
doc.add_paragraph('逐距离门相乘完成方位聚焦。方位分辨率为：')
make_omml_paragraph(doc, 'ρ_a = L_a/2 = 1/2 = 0.5 m', eq_num=9)

doc.add_heading('步骤6：方位IFFT输出图像', level=2)
doc.add_paragraph('对方位频域进行IFFT，得到最终SAR图像：')
make_omml_paragraph(doc,
    's₅(τ,η) = A·p_r(τ-2R₀/c)·p_a(η)·exp{-j4πf₀R₀/c}',
    eq_num=10)
doc.add_page_break()


# ============ 三、系统参数设计 ============
h = doc.add_heading('三、系统参数设计', level=1)
add_bookmark(h, 'bm_ch3')
doc.add_paragraph('本仿真采用机载X波段SAR系统，参数设计如下表所示：')
doc.add_paragraph()
doc.add_paragraph('表1 RD算法仿真参数').bold = True
table = doc.add_table(rows=1, cols=3)
table.style = 'Table Grid'
hdr = table.rows[0].cells
hdr[0].text = '参数名称'; hdr[1].text = '符号'; hdr[2].text = '设计值'
params = [
    ('载波频率','f₀','10 GHz'),('波长','λ','0.03 m'),('信号带宽','B','300 MHz'),
    ('脉冲宽度','Tr','2.5 μs'),('距离调频斜率','Kr','1.2×10¹⁴ Hz/s'),
    ('距离采样率','Fr','360 MHz'),('距离分辨率','ρ_r','0.5 m'),
    ('方位分辨率','ρ_a','0.5 m'),('平台速度','V','150 m/s'),
    ('天线方位向长度','La','1 m'),('多普勒带宽','Ba','300 Hz'),
    ('PRF','Fa','400 Hz'),('载机高度','H','3000 m'),
    ('侧视角','θ','45°'),('中心斜距','R_etac','4243 m'),
    ('场景(距离向)','2Xo','1000 m'),('场景(方位向)','2Yo','500 m'),
    ('点间距','spacing','2 m'),('字母高度','letter_h','280 m'),
    ('字母宽度','letter_w','160 m'),('RCMC插值核','P','8点'),
]
for name, sym, val in params:
    row = table.add_row().cells
    row[0].text = name; row[1].text = sym; row[2].text = val
doc.add_paragraph()
doc.add_paragraph('参数设计说明：')
doc.add_paragraph('· 距离分辨率 ρ_r = c/(2B) = 0.5m → B = 300MHz')
doc.add_paragraph('· 方位分辨率 ρ_a = La/2 = 0.5m → La = 1m')
doc.add_paragraph('· PRF=400Hz > Ba=300Hz，满足方位无模糊')
doc.add_paragraph('· Fr=360MHz > B=300MHz，满足距离向奈奎斯特采样')
doc.add_paragraph('· 场景幅宽：距离向1000m × 方位向500m')
doc.add_page_break()


# ============ 四、RD算法仿真结果 ============
h = doc.add_heading('四、RD算法仿真结果', level=1)
add_bookmark(h, 'bm_ch4')
doc.add_heading('步骤1：初始点目标分布', level=2)
doc.add_paragraph('场景中布设4个边缘点(1000m×500m矩形)和字母LWB离散点目标。')
doc.add_paragraph('[图1: 点目标初始分布]')
doc.add_heading('步骤2：原始回波数据', level=2)
doc.add_paragraph('对所有点目标叠加得到二维原始回波数据矩阵。')
doc.add_paragraph('[图2: 原始回波幅度图]')
doc.add_paragraph('[图3: 原始回波实部图]')
doc.add_heading('步骤3：距离脉冲压缩', level=2)
doc.add_paragraph('频域匹配滤波后各点目标在距离向聚焦，方位向表现为距离走动轨迹。')
doc.add_paragraph('[图4: 距离压缩后]')
doc.add_heading('步骤4：距离走动校正（RCMC）', level=2)
doc.add_paragraph('8点Sinc插值校正距离弯曲量，将徙动曲线拉直。')
doc.add_paragraph('[图5: RCMC校正后]')
doc.add_heading('步骤5：方位压缩与最终成像', level=2)
doc.add_paragraph('方位压缩后得到最终SAR图像，dB图采用-40dB动态范围，jet色表。')
doc.add_paragraph('[图6: RD成像结果(幅度)]')
doc.add_paragraph('[图7: RD成像结果(dB)]')
doc.add_heading('步骤6：边缘点成像结果分析', level=2)
doc.add_paragraph(
    '4个边缘点(Xc±500, Yc±250)均清晰聚焦，验证RD算法全场景有效性。'
    '边缘点与中心点聚焦质量一致，Ka空变性影响可忽略。')
doc.add_page_break()

# ============ 五、心得体会 ============
h = doc.add_heading('五、RD算法仿真心得体会', level=1)
add_bookmark(h, 'bm_ch5')
doc.add_paragraph('1）RD算法兼具成熟、简单、高效和精确等优点，本次仿真对其有了深入理解。')
doc.add_paragraph('2）坐标系一致性很重要，imagesc默认Y轴朝下，需用axis xy统一。')
doc.add_paragraph('3）RCMC是核心操作，8点Sinc插值精度与计算量需权衡。')
doc.add_paragraph('4）场景幅宽设计需考虑脉冲展宽效应(c·Tr/2≈375m)。')
doc.add_paragraph('5）本次大作业对SAR完整信号处理链有了系统性认识。')
doc.add_page_break()


# ============ 附录：完整MATLAB代码 ============
h = doc.add_heading('附录：完整MATLAB代码', level=1)
add_bookmark(h, 'bm_appendix')
doc.add_paragraph('以下为SAR_RD_imaging.m的完整源代码：')
doc.add_paragraph()
code_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'SAR_RD_imaging.m')
with open(code_path, 'r', encoding='utf-8') as f:
    code_content = f.read()
code_para = doc.add_paragraph()
run = code_para.add_run(code_content)
run.font.size = Pt(9)
run.font.name = 'Courier New'
run.element.rPr.rFonts.set(qn('w:eastAsia'), '宋体')

# ============ 保存 ============
output_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'SAR_RD_课程报告.docx')
doc.save(output_path)
print(f'报告已生成: {output_path}')
