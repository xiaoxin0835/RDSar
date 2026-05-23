%%乘除法时注意先后顺序
%%这个方法比的是相位，所以不用取dB

clc; clear;
%目标
N = 1;
angle = 0;
target = 3;


%x（t）模拟
f_0 = 16e9;
B = 20e6;
A = 0.225e3;
t_p = 1/A;
k = 2*pi*B/t_p;
c = 3e8;
lanmeda = c/f_0 ;
%小天线参数
N_ti = 17;
N_1 = -(N_ti-1)/2:(N_ti-1)/2;
d_ti =lanmeda/2;
BW = 50.8*2/(N_ti*cosd(angle));

t = 0:9;
% x = exp(1j*(2*pi*f_0*t+(k*t.^2)/2));

a = zeros(N_ti,1);
a = exp(1j*N_1.'*2*pi*d_ti*sind(angle)/lanmeda);
cha = [1,1,1,1,1,1,1,1,0,-1,-1,-1,-1,-1,-1,-1,-1];

W = a ;
W_2 = a.*cha.';
% y = X*W;
% figure;
% plot(real(y))


theta = angle-6:0.1:angle+6;
a_theta = exp(1j*2*pi*N_1'*d_ti*sind(theta)/lanmeda);
pattern = zeros(size(theta));
pattern = W' * a_theta;
pattern_2 = W_2'*a_theta;

%画和差波束图
he = pattern / max(abs(pattern));
cha = pattern_2/ max(abs(pattern_2));
figure;
plot(theta, 20*log10(he), 'LineWidth',1.5); 
hold on;
plot(theta, 20*log10(cha), 'LineWidth',1.5); 
%%MRC
MRC = -imag(pattern_2./pattern);
figure;
plot(theta, MRC, 'LineWidth',1.2);
title('鉴角曲线');
snr = 2:1:20;
M = 2000;
ave = zeros(1, M);
RMSE = zeros(1,length(snr));
RMSE_li = zeros(1,length(snr));
x = exp(1i*2*pi*N_1'*d_ti*sind(target)/lanmeda);
for j = 1:length(snr)
    for i = 1:M        
        x1 = awgn(x, snr(j), 'measured');
        y1 = W' * x1;
        y2 = W_2' * x1;
        MRC1 = -imag(y2 ./ y1);   
        [~,c] = min(abs(MRC-MRC1));
        ave(i) = (theta(c) - target)^2; 
    end
    RMSE(j) = sqrt(mean(ave));
    RMSE_li(j) = BW/(sqrt(N_ti*10.^(snr(j)/10))*2);
end

figure;
plot(snr,RMSE)
hold on;
plot(snr,RMSE_li)






