%%机载X波段SAR回波仿真与RD成像算法
%%分辨率0.5m，场景点目标：LWB字母 + 4个边缘点
%%参考SAR_RD_Algorithm_Spec文档

clc; clear; close all;

%% 系统参数设计
c = 3e8;                    %光速
f0 = 10e9;                  %载波频率 X波段
lamda = c/f0;               %波长 0.03m
B = 300e6;                  %信号带宽 对应距离分辨率0.5m
Tr = 2.5e-6;               %脉冲宽度
Kr = B/Tr;                  %距离向调频斜率
Fr = 360e6;                 %距离向采样率 1.2*B
Vr = 150;                   %平台飞行速度
H = 3000;                   %平台高度
La = 1;                     %天线方位向长度
rho_a = 0.5;               %方位分辨率
Ba = 2*Vr/La;              %多普勒带宽 300Hz
PRF = 400;                  %脉冲重复频率
Fa = PRF;                   %方位向采样率
theta_look = 45*pi/180;    %侧视角 45度
Rc = H/cos(theta_look);    %中心斜距
im = sqrt(-1);

%% 场景参数
%场景范围：方位向600m x 地距向600m
Xa = 600;                   %方位向场景宽度
Xr = 600;                   %地距向场景宽度
%中心地距坐标
Xc_ground = H*tan(theta_look); %地距中心

%% 生成点目标坐标 - LWB字母 + 4个边缘点
%字母点间距2m，防止主瓣重叠
spacing = 2.0;

%--- 字母 L ---
L_pts = [];
%竖笔画
for yy = 0:spacing:40
    L_pts = [L_pts; 0, yy];
end
%横笔画
for xx = spacing:spacing:24
    L_pts = [L_pts; xx, 0];
end

%--- 字母 W ---
W_pts = [];
%左竖
for yy = 0:spacing:40
    W_pts = [W_pts; 0, yy];
end
%左斜下
for k = 1:6
    W_pts = [W_pts; k*spacing, 40-k*spacing*40/12];
end
%中竖上
for k = 1:6
    W_pts = [W_pts; 6*spacing+k*spacing, (k)*spacing*40/12];
end
%右斜下
for k = 1:6
    W_pts = [W_pts; 12*spacing+k*spacing, 40-k*spacing*40/12];
end
%右竖
for yy = 0:spacing:40
    W_pts = [W_pts; 24, yy];
end

%--- 字母 B ---
B_pts = [];
%竖笔画
for yy = 0:spacing:40
    B_pts = [B_pts; 0, yy];
end
%上横
for xx = spacing:spacing:16
    B_pts = [B_pts; xx, 40];
end
%中横
for xx = spacing:spacing:16
    B_pts = [B_pts; xx, 20];
end
%下横
for xx = spacing:spacing:16
    B_pts = [B_pts; xx, 0];
end
%上弧（右侧竖段上半）
for yy = 22:spacing:38
    B_pts = [B_pts; 18, yy];
end
%下弧（右侧竖段下半）
for yy = 2:spacing:18
    B_pts = [B_pts; 18, yy];
end

%组合字母，设定字母间偏移（方位向排列）
offset_L = [-200, -100];    %L字母中心偏移
offset_W = [-40, -100];     %W字母中心偏移
offset_B = [140, -100];     %B字母中心偏移

targets_letter = [];
for k = 1:size(L_pts,1)
    targets_letter = [targets_letter; L_pts(k,1)+offset_L(1), L_pts(k,2)+offset_L(2)];
end
for k = 1:size(W_pts,1)
    targets_letter = [targets_letter; W_pts(k,1)+offset_W(1), W_pts(k,2)+offset_W(2)];
end
for k = 1:size(B_pts,1)
    targets_letter = [targets_letter; B_pts(k,1)+offset_B(1), B_pts(k,2)+offset_B(2)];
end

%4个边缘点（场景四角）
targets_edge = [ -Xa/2, -Xr/2;
                  Xa/2, -Xr/2;
                 -Xa/2,  Xr/2;
                  Xa/2,  Xr/2];

%合并所有目标 [方位向偏移, 地距向偏移]
targets_all = [targets_letter; targets_edge];
Ntarget = size(targets_all, 1);

%将地距偏移转换为斜距坐标
%目标三维坐标: x_i = Xc_ground + dr_ground, y_i = azimuth_offset, z_i = 0
%雷达坐标: (Xc_ground, V*eta, H) -> 简化为正侧视
%这里用 (地距方向x, 方位方向y, 0)
target_x = Xc_ground + targets_all(:,2);  %地距方向
target_y = targets_all(:,1);               %方位方向

%% 计算观测几何
Rmin = sqrt(H^2 + (Xc_ground - Xr/2)^2);
Rmax = sqrt(H^2 + (Xc_ground + Xr/2)^2);
Ls = 0.886*Rc*lamda/La;    %合成孔径长度
Ta = Ls/Vr;                 %目标照射时间
Ra = Ls + Xa;               %方位向行走距离

%% 时间轴
eta = 0:1/Fa:Ra/Vr-1/Fa;           %慢时间轴
tao = 2*Rmin/c-Tr/2:1/Fr:2*Rmax/c+Tr/2-1/Fr;  %快时间轴
Na = length(eta);                    %方位向采样点数
Nr = length(tao);                    %距离向采样点数

fprintf('方位向采样点数 Na = %d\n', Na);
fprintf('距离向采样点数 Nr = %d\n', Nr);

%% 回波仿真
signal_receive = zeros(Na, Nr);
y_platform = -Ra/2 + Vr*eta;        %飞机方位向位置

for i = 1:Ntarget
    %瞬时斜距
    R_eta = sqrt(target_x(i)^2 + (target_y(i) - y_platform).^2 + H^2);
    %方位向包络（合成孔径内）
    for j = 1:Na
        if abs(target_y(i) - y_platform(j)) < Ls/2
            tau_delay = 2*R_eta(j)/c;
            signal_receive(j,:) = signal_receive(j,:) + ...
                rectpuls(tao - tau_delay, Tr) .* ...
                exp(-im*4*pi*f0*R_eta(j)/c) .* ...
                exp(im*pi*Kr*(tao - tau_delay).^2);
        end
    end
end

%% 绘制回波实部
figure;
imagesc(tao*1e6, y_platform, real(signal_receive));
xlabel('快时间/\mus'); ylabel('方位向位置/m');
title('原始回波实部'); colorbar;

%% 距离向压缩
%构建距离向匹配滤波器（频域）
NFFT_r = 2^nextpow2(Nr);
f_r = linspace(-Fr/2, Fr/2, NFFT_r);
H_r = exp(im*pi*f_r.^2/Kr);        %匹配滤波器

signal_rc = zeros(Na, NFFT_r);
for i = 1:Na
    signal_rc(i,:) = ifft(fft(signal_receive(i,:), NFFT_r) .* fftshift(H_r), NFFT_r);
end
signal_rc = signal_rc(:, 1:Nr);     %截取有效长度

%距离轴（地距）
r_axis = sqrt((tao*c/2).^2 - H^2);

figure;
imagesc(r_axis, y_platform, abs(signal_rc));
xlabel('地距/m'); ylabel('方位向位置/m');
title('距离压缩后'); colorbar;

%% 方位向FFT -> RD域
Signal_RD = zeros(Na, Nr);
for i = 1:Nr
    Signal_RD(:,i) = fftshift(fft(signal_rc(:,i), Na));
end

%% RCMC - 距离走动校正（Sinc插值）
f_eta = linspace(-Fa/2, Fa/2, Na);  %方位频率轴
P = 8;                               %Sinc插值核点数
Signal_RCMC = zeros(Na, Nr);

for m = 1:Na
    %距离走动量（依赖方位频率）
    delta_R = lamda^2*Rc*(f_eta(m))^2/(8*Vr^2);
    delta_n = round(2*delta_R*Fr/c);
    frac_n = 2*delta_R*Fr/c - delta_n;
    
    for n = P/2+1:Nr-P/2
        for k = -P/2:P/2-1
            idx = n + delta_n + k;
            if idx >= 1 && idx <= Nr
                Signal_RCMC(m,n) = Signal_RCMC(m,n) + ...
                    Signal_RD(m, idx) * sinc(frac_n - k);
            end
        end
    end
end

figure;
imagesc(r_axis, y_platform, abs(ifft(Signal_RCMC,[],1)));
xlabel('地距/m'); ylabel('方位向位置/m');
title('距离徙动校正后'); colorbar;

%% 方位向压缩
%方位向匹配滤波器（随距离空变）
%Ka_vec = 2*Vr^2./(lamda * sqrt((tao*c/2).^2));  %空变调频率（参考）

signal_final = zeros(Na, Nr);
for k = 1:Nr
    R0 = tao(k)*c/2;  %该距离门对应的最近斜距
    %方位匹配滤波器
    H_az = exp(im*4*pi*R0/lamda * sqrt(1 - (lamda*f_eta/(2*Vr)).^2));
    signal_final(:,k) = ifft(Signal_RCMC(:,k) .* H_az.', Na);
end

%% 最终成像结果
figure;
imagesc(r_axis, y_platform, abs(signal_final));
xlabel('地距/m'); ylabel('方位向/m');
title('RD成像结果 - LWB字母与边缘点');
colorbar; colormap('jet');

%% 成像结果dB显示
figure;
img_dB = 20*log10(abs(signal_final)/max(abs(signal_final(:))) + 1e-10);
imagesc(r_axis, y_platform, img_dB);
caxis([-40 0]);
xlabel('地距/m'); ylabel('方位向/m');
title('RD成像结果(dB) - LWB');
colorbar; colormap('jet');

fprintf('成像完成！\n');
