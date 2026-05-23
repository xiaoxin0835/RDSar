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
Xo = 500;                   %距离向半幅宽500，总宽1000m(横轴)
Yo = 250;                   %方位向半幅宽250，总宽500m(纵轴)

%% 点目标生成 - 字母LWB + 边缘点
%%注意：plot中Y轴正方向朝上，y0为物理底部，y0+letter_h为物理顶部

% 边缘4个点(强制要求)
edge_targets = [Xc-Xo, Yc-Yo;
                Xc-Xo, Yc+Yo;
                Xc+Xo, Yc-Yo;
                Xc+Xo, Yc+Yo];

%% 字母点目标生成 (严格按照笛卡尔坐标系 Y向上为正)
spacing = 2.0;      %相邻点间距2m
letter_h = 280;     %字母高度(纵轴500m的约2/3)
letter_w = 160;     %字母宽度
gap = 50;           %字母间距

total_w = 3*letter_w + 2*gap;
x_start = Xc - total_w/2;    %距离向整体居中
y_start = Yc - letter_h/2;   %此处 y_start 即为字母的"最底端"

letter_targets = [];

%% 字母 L
x0 = x_start;
y0 = y_start;
%竖笔画：从底端 y0 向上延伸到 y0+letter_h
pts_y = (y0:spacing:y0+letter_h)';
letter_targets = [letter_targets; ones(size(pts_y))*x0, pts_y];
%横笔画(底部)：Y固定在底部 y0，X向右延伸
pts_x2 = (x0:spacing:x0+letter_w)';
letter_targets = [letter_targets; pts_x2, ones(size(pts_x2))*y0];

%% 字母 W
x0 = x_start + letter_w + gap;
y0 = y_start;
seg_w = letter_w/4;
n_pts = round(letter_h/spacing);
%第一笔：从左上(y0+H)落至左下(y0)
for k = 0:n_pts
    t = k/n_pts;
    letter_targets = [letter_targets; x0 + t*seg_w, y0 + letter_h - t*letter_h];
end
%第二笔：从左下(y0)升至中峰(y0+H/2)
for k = 0:n_pts
    t = k/n_pts;
    letter_targets = [letter_targets; x0 + seg_w + t*seg_w, y0 + t*(letter_h/2)];
end
%第三笔：从中峰(y0+H/2)落至右下(y0)
for k = 0:n_pts
    t = k/n_pts;
    letter_targets = [letter_targets; x0 + 2*seg_w + t*seg_w, y0 + letter_h/2 - t*(letter_h/2)];
end
%第四笔：从右下(y0)升至右上(y0+H)
for k = 0:n_pts
    t = k/n_pts;
    letter_targets = [letter_targets; x0 + 3*seg_w + t*seg_w, y0 + t*letter_h];
end

%% 字母 B
x0 = x_start + 2*(letter_w + gap);
y0 = y_start;
%竖笔画 (左侧)
pts_y = (y0:spacing:y0+letter_h)';
letter_targets = [letter_targets; ones(size(pts_y))*x0, pts_y];
%三条横线
pts_x3 = (x0:spacing:x0+letter_w*0.7)';
letter_targets = [letter_targets; pts_x3, ones(size(pts_x3))*y0];               % 底部横线
letter_targets = [letter_targets; pts_x3, ones(size(pts_x3))*(y0+letter_h/2)];  % 中部横线
letter_targets = [letter_targets; pts_x3, ones(size(pts_x3))*(y0+letter_h)];    % 顶部横线
%两个半圆弧
r_arc = letter_h/4;
x_center = x0 + letter_w*0.7;
theta_arc = linspace(-pi/2, pi/2, round(pi*r_arc/spacing))';
%下半圆弧
letter_targets = [letter_targets; x_center + r_arc*cos(theta_arc), y0 + r_arc + r_arc*sin(theta_arc)];
%上半圆弧
letter_targets = [letter_targets; x_center + r_arc*cos(theta_arc), y0 + 3*r_arc + r_arc*sin(theta_arc)];

%% 合并所有目标
target = [edge_targets; letter_targets];
Ntarget = size(target, 1);
fprintf('总点目标数: %d\n', Ntarget);

%% 显示初始点目标分布
figure;
plot(target(:,1), target(:,2), 'r.', 'MarkerSize', 8);
hold on;
plot(edge_targets(:,1), edge_targets(:,2), 'r.', 'MarkerSize', 8);
xlabel('距离向 X /m');
ylabel('方位向 Y /m');
title('点目标初始分布(字母LWB + 边缘点)');
axis equal;
grid on;

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
axis xy;    % 将Y轴反转回来，保证图像显示符合真实空间几何关系
xlabel('距离向 /m');
ylabel('方位向 /m');
title('RD成像结果(dB)');
caxis([-40 0]);

% 不限制显示范围，自动适应数据
colorbar;
colormap('jet');

fprintf('成像完成！\n');
