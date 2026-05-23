%%机载X波段SAR回波仿真与RD成像算法
%%字母LWB + 边缘点目标布设
%%分辨率0.5m，幅宽500m

close all; clear; clc;
%% 系统参数设计
c = 3e8;                    %光速
f0 = 10e9;                  %载波频率 X波段
lamda = c/f0;               %波长 0.03m
B = 300e6;                  %信号带宽 300MHz
rho_r = 0.5;               %距离向分辨率
rho_a = 0.5;               %方位向分辨率
Tr = 2.5e-6;               %脉冲宽度
Kr = B/Tr;                  %距离向调频斜率
Fr = 360e6;                 %距离向采样率 1.2*B
Vr = 150;                   %平台速度
La = 2*rho_a;               %天线方位向长度 1m
Ba = 2*Vr/La;               %多普勒带宽 300Hz
Fa = 400;                   %方位向采样率(PRF)
H = 3000;                   %平台高度
theta = 45*pi/180;          %侧视角
R_etac = H/cos(theta);      %中心斜距
Ka = 2*Vr^2/lamda/R_etac;   %方位向调频率
Ls = 0.886*R_etac*lamda/La;  %合成孔径长度
Ta = Ls/Vr;                 %目标照射时间
im = sqrt(-1);              %虚数单位

%% 场景设置
Xc = sqrt(R_etac^2 - H^2); %场景中心地距坐标(距离向)
Yc = 0;                     %场景中心方位向坐标
Xo = 300;                   %距离向半幅宽(地距)
Yo = 300;                   %方位向半幅宽

%% 点目标生成 - 字母LWB + 边缘点
%%注意：imagesc中 X为水平轴(距离向)，Y为垂直轴(方位向)
%%因此字母宽度->X(距离向)，字母高度->Y(方位向)

% 边缘4个点(强制要求)
edge_targets = [Xc-Xo, Yc-Yo;
                Xc-Xo, Yc+Yo;
                Xc+Xo, Yc-Yo;
                Xc+Xo, Yc+Yo];

% 字母参数设置
spacing = 2.0;      %相邻点间距2m(大于分辨率)
letter_h = 80;      %字母高度(映射到Y方位向)
letter_w = 50;      %字母宽度(映射到X距离向)
gap = 40;           %字母间距(沿X距离向)

%三个字母总宽度(沿距离向X排列)
total_w = 3*letter_w + 2*gap;

%字母起始位置：距离向居中，方位向居中
x_start = Xc - total_w/2;    %距离向起始
y_start = Yc - letter_h/2;   %方位向起始(字母高度方向)

letter_targets = [];

%% 字母 L
x0 = x_start;
y0 = y_start;
%竖笔画：沿Y(方位向)展开，X不变
pts_y = (y0:spacing:y0+letter_h)';
pts_x = ones(size(pts_y))*x0;
letter_targets = [letter_targets; pts_x, pts_y];
%横笔画(底部)：沿X(距离向)展开，Y固定在底部
pts_x2 = (x0:spacing:x0+letter_w)';
pts_y2 = ones(size(pts_x2))*(y0+letter_h);
letter_targets = [letter_targets; pts_x2, pts_y2];

%% 字母 W
x0 = x_start + letter_w + gap;
y0 = y_start;
seg_w = letter_w/4;  %W分4段(沿X方向)
n_pts = round(letter_h/spacing);
%第一笔：从左上到左下谷(Y从上到下，X向右偏移一点)
for k = 0:n_pts
    t_ratio = k/n_pts;
    py = y0 + t_ratio*letter_h;
    px = x0 + t_ratio*seg_w;
    letter_targets = [letter_targets; px, py];
end
%第二笔：从左下谷到中间峰顶(Y从下到中，X继续右移)
for k = 0:n_pts
    t_ratio = k/n_pts;
    py = y0 + letter_h - t_ratio*(letter_h/2);
    px = x0 + seg_w + t_ratio*seg_w;
    letter_targets = [letter_targets; px, py];
end
%第三笔：从中间峰顶到右下谷(Y从中到下，X继续右移)
for k = 0:n_pts
    t_ratio = k/n_pts;
    py = y0 + letter_h/2 + t_ratio*(letter_h/2);
    px = x0 + 2*seg_w + t_ratio*seg_w;
    letter_targets = [letter_targets; px, py];
end
%第四笔：从右下谷到右上(Y从下到上，X继续右移)
for k = 0:n_pts
    t_ratio = k/n_pts;
    py = y0 + letter_h - t_ratio*letter_h;
    px = x0 + 3*seg_w + t_ratio*seg_w;
    letter_targets = [letter_targets; px, py];
end

%% 字母 B
x0 = x_start + 2*(letter_w + gap);
y0 = y_start;
%竖笔画：沿Y(方位向)展开
pts_y = (y0:spacing:y0+letter_h)';
pts_x = ones(size(pts_y))*x0;
letter_targets = [letter_targets; pts_x, pts_y];
%上横：沿X(距离向)展开，Y在顶部
pts_x2 = (x0:spacing:x0+letter_w*0.7)';
pts_y2 = ones(size(pts_x2))*y0;
letter_targets = [letter_targets; pts_x2, pts_y2];
%中横：沿X(距离向)展开，Y在中间
pts_x3 = (x0:spacing:x0+letter_w*0.7)';
pts_y3 = ones(size(pts_x3))*(y0+letter_h/2);
letter_targets = [letter_targets; pts_x3, pts_y3];
%下横：沿X(距离向)展开，Y在底部
pts_x4 = (x0:spacing:x0+letter_w*0.7)';
pts_y4 = ones(size(pts_x4))*(y0+letter_h);
letter_targets = [letter_targets; pts_x4, pts_y4];
%上半圆弧(右侧凸出)
r_arc = letter_h/4;
x_center_up = x0 + letter_w*0.7;     %圆心X(距离向偏右)
y_center_up = y0 + letter_h/4;       %圆心Y(上半部分中心)
theta_arc = linspace(-pi/2, pi/2, round(pi*r_arc/spacing));
for k = 1:length(theta_arc)
    px = x_center_up + r_arc*cos(theta_arc(k));  %X方向凸出
    py = y_center_up + r_arc*sin(theta_arc(k));  %Y方向展开
    letter_targets = [letter_targets; px, py];
end
%下半圆弧(右侧凸出)
x_center_dn = x0 + letter_w*0.7;
y_center_dn = y0 + 3*letter_h/4;
for k = 1:length(theta_arc)
    px = x_center_dn + r_arc*cos(theta_arc(k));
    py = y_center_dn + r_arc*sin(theta_arc(k));
    letter_targets = [letter_targets; px, py];
end

%% 合并所有目标
target = [edge_targets; letter_targets];
Ntarget = size(target, 1);
fprintf('总点目标数: %d\n', Ntarget);

%% 显示初始点目标分布
figure;
plot(target(:,1), target(:,2), 'r.', 'MarkerSize', 8);
hold on;
plot(edge_targets(:,1), edge_targets(:,2), 'bs', 'MarkerSize', 12, 'LineWidth', 2);
xlabel('距离向 X /m');
ylabel('方位向 Y /m');
title('点目标初始分布(字母LWB + 边缘点)');
axis equal;
grid on;
legend('字母点目标', '边缘点');

%% 观测几何计算
Rmin = sqrt(H^2 + (Xc-Xo)^2);   %最近斜距
Rmax = sqrt(H^2 + (Xc+Xo)^2);   %最远斜距
Ra = Ls + 2*Yo;                    %方位向行走距离

%% 生成时间轴
eta = 0:1/Fa:Ra/Vr-1/Fa;          %慢时间轴
tao = 2*Rmin/c-Tr/2:1/Fr:2*Rmax/c+Tr/2-1/Fr; %快时间轴
Na = length(eta);                   %方位向采样点数
Nr = length(tao);                   %距离向采样点数
fprintf('方位向采样点数: %d\n', Na);
fprintf('距离向采样点数: %d\n', Nr);

%% 回波仿真
signal_receive = zeros(Na, Nr);     %回波矩阵
y = -Ra/2 + Vr*eta;                 %飞机方位向位置
A0 = 1;                             %目标幅度

for i = 1:Ntarget
    R_eta_i = sqrt(target(i,1)^2 + (target(i,2)-y).^2 + H^2); %瞬时斜距
    for j = 1:Na
        signal_receive(j,:) = signal_receive(j,:) + ...
            A0*rectpuls(tao-2*R_eta_i(j)/c, Tr) .* ...
            (abs(target(i,2)-y(j)) < Ls/2) .* ...
            exp(-im*4*pi*f0*R_eta_i(j)/c) .* ...
            exp(im*pi*Kr*(tao-2*R_eta_i(j)/c).^2);
    end
end

%% 绘制回波数据
figure;
imagesc(abs(signal_receive));
xlabel('距离向(采样点)');
ylabel('方位向(采样点)');
title('原始回波幅度');
colorbar;

figure;
imagesc(real(signal_receive));
xlabel('距离向(采样点)');
ylabel('方位向(采样点)');
title('原始回波实部');
colorbar;

%% 第一步：距离向压缩
t_ref = -Tr/2:1/Fr:Tr/2-1/Fr;
signal_ref = exp(im*pi*Kr*t_ref.^2);   %参考信号
NFFT_r = Nr + length(signal_ref) - 1;   %FFT点数

signal_rc = zeros(Na, NFFT_r);
for i = 1:Na
    signal_rc(i,:) = ifft(fft(signal_receive(i,:), NFFT_r) .* ...
                     fft(conj(fliplr(signal_ref)), NFFT_r));
end
%取出完全卷积部分
signal_matched = signal_rc(:, length(signal_ref)/2:length(signal_ref)/2+Nr-1);

%绘制距离压缩结果
r_axis = ((tao*c/2).^2 - H^2).^(1/2); %地距坐标
figure;
imagesc(r_axis, y, abs(signal_matched));
xlabel('距离向/m');
ylabel('方位向/m');
title('距离压缩后');
colorbar;

%% 第二步：方位向FFT(转至RD域)
Signal_azimuth_FFT = zeros(Na, Nr);
for i = 1:Nr
    Signal_azimuth_FFT(:,i) = fftshift(fft(signal_matched(:,i), Na));
end

%% 第三步：距离徙动校正RCMC(Sinc插值)
Signal_RCMC = zeros(Na, Nr);
f_eta = linspace(-Fa/2, Fa/2, Na);      %多普勒频率轴
P = 8;                                    %Sinc插值核点数
delta_R = lamda^2*R_etac*(f_eta).^2/8/Vr^2; %距离走动量
delta_n = round(2*delta_R*Fr/c);          %整数偏移
fracn = 2*delta_R*Fr/c - delta_n;         %小数偏移

for m = 1:Na
    for n = P/2+1:Nr
        for i = -P/2:1:P/2-1
            if n+delta_n(m)+i > Nr
                Signal_RCMC(m,n) = Signal_RCMC(m,n) + ...
                    Signal_azimuth_FFT(m,Nr)*sinc(fracn(m)-i);
            elseif n+delta_n(m)+i < 1
                Signal_RCMC(m,n) = Signal_RCMC(m,n) + ...
                    Signal_azimuth_FFT(m,1)*sinc(fracn(m)-i);
            else
                Signal_RCMC(m,n) = Signal_RCMC(m,n) + ...
                    Signal_azimuth_FFT(m,n+delta_n(m)+i)*sinc(fracn(m)-i);
            end
        end
    end
end

figure;
imagesc(r_axis, y, abs(ifft(Signal_RCMC)));
xlabel('距离向/m');
ylabel('方位向/m');
title('距离徙动校正后');
colorbar;

%% 第四步：方位向压缩
signal_processed = zeros(Na, Nr);
H_az = exp(-im*pi*f_eta.^2/Ka);          %方位向匹配滤波器

for k = 1:Nr
    signal_processed(:,k) = ifft(H_az.' .* Signal_RCMC(:,k));
end

%% 最终成像结果
figure;
imagesc(r_axis, y, abs(signal_processed));
xlabel('距离向/m');
ylabel('方位向/m');
title('RD成像结果(幅度)');
colorbar;
colormap('jet');

%dB显示
figure;
img_dB = 20*log10(abs(signal_processed)/max(abs(signal_processed(:)))+eps);
imagesc(r_axis, y, img_dB);
xlabel('距离向/m');
ylabel('方位向/m');
title('RD成像结果(dB)');
caxis([-40 0]);
colorbar;
colormap('jet');

fprintf('成像完成！\n');
