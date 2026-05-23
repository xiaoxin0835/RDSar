close all; clear; clc;
%% 仿真参数
%参数来源表4.1，P98
%2023.6.23 lbb
R_etac=30e3;%景中心斜距
H=10e3;%飞行高度
Tr=10e-6;%脉冲宽度
B=100e6;%信号带宽
Kr=B/Tr;%距离脉冲调频率
Fr=1.2*B;%距离采样率
Vr=250;%雷达有效速度
f0=9.4e9;%载波频率
c=3e8;%光速
lamda=c/f0;%波长
Ka=2*Vr^2/lamda/R_etac;%方位向调频率
La=1;%天线真实孔径
Ls=0.886*R_etac*lamda/La;%合成孔径长度
Ta=Ls/Vr;%目标照射时间
Bw_doppler=0.886*2*Vr/La;%多普勒带宽
Fa=600;%方位向采样率
im=sqrt(-1);%虚数单位
%% 成像区域[Xc-X0,Xc+X0; Yc-Y0,Yc+Y0]
Xc = sqrt(R_etac^2-H^2);
Yc = 0;
Xo = 500;
Yo =300;
Rmin=sqrt(H^2+(Xc-Xo)^2);%观测场景距飞机的最近距离
Rmax=sqrt(H^2+(Xc+Xo)^2);%观测场景距飞机的最远距离
Ra=Ls+2*Yo;%正侧视时雷达在方位向行走距离
%% 目标位置
target = [Xc,Yc;
          Xc-300,Yc+200;
          Xc-300,Yc-200];  
%% 生成回波
eta=0:1/Fa:Ra/Vr-1/Fa;%慢时间轴
tao=2*Rmin/c-Tr/2:1/Fr:2*Rmax/c+Tr/2-1/Fr;%快时间轴
Na=length(eta);%方位向采样点数
Nr=length(tao);%距离向采样点数
signal_receive=zeros(Na,Nr);%回波
y=-Ra/2+Vr*eta;%飞机的位置
R_eta=zeros(size(target,1),Na);%瞬时斜距
A0=1;%幅度
for i=1:size(target,1)
    R_eta(i,:)=sqrt(target(i,1)^2+(target(i,2)-y).^2+H^2);
     for j=1:Na
         signal_receive(j,:)=A0*rectpuls(tao-2*R_eta(i,j)/c,Tr).*(abs(target(i,2)-y(j))<Ls/2).*...
         exp(-im*4*pi*f0*R_eta(i,j)/c).*exp(im*pi*Kr*(tao-2*R_eta(i,j)/c).^2)+signal_receive(j,:);
    end
end
%% 距离压缩
t=-Tr/2:1/Fr:Tr/2-1/Fr;
signal_ref=exp(im*pi*Kr*t.^2);%参考信号
NFFT=Nr+length(signal_ref)-1;%FFT点数
y1=zeros(Na,NFFT);
for i=1:Na
   y1(i,:)=ifft(fft(signal_receive(i,:),NFFT).*fft(conj(fliplr(signal_ref)),NFFT));
end
signal_matched=y1(:,length(signal_ref)/2:length(signal_ref)/2+Nr-1);%取出完全卷积点
r=((tao*c/2).^2-H^2).^(1/2);%距离向横坐标
figure;
[R,Y] = meshgrid(r,y);mesh(R,Y,abs(signal_matched));view(0,90);xlim([27800 28300]);
xlabel('距离向');
title('距离压缩后');
%% RCMC
Signal_azimuth_FFT=zeros(Na,Nr);
for i=1:Nr
  Signal_azimuth_FFT(:,i)=fftshift(fft(signal_matched(:,i),Na));%方位向FFT
end
%截断sinc函数插值
Signal_RCMC=zeros(Na,Nr);
f_eta=linspace(-Fa/2,Fa/2,Na);
P=8;%截断sinc插值的核函数的点数
delta_R=lamda^2*R_etac*(f_eta).^2/8/Vr^2;
delta_n=round(2*delta_R*Fr/c);
fracn=2*delta_R*Fr/c-delta_n;
for m=1:Na
    for n=P/2+1:Nr
        for i=-P/2:1:P/2-1
            if n+delta_n(m)+i>Nr
               Signal_RCMC(m,n)=Signal_RCMC(m,n)+Signal_azimuth_FFT(m,Nr)*sinc(delta_n(m)-i); %防止溢出
            else
               Signal_RCMC(m,n)= Signal_RCMC(m,n)+Signal_azimuth_FFT(m,n+delta_n(m)+i)*sinc(fracn(m)-i);
            end
        end       
    end
end
figure;
[R,Y] = meshgrid(r,y);
mesh(R,Y,abs(ifft(Signal_RCMC)));view(0,90);xlim([27800 28300]);
title('距离徙动校正')
xlabel('距离向');
%% 方位压缩
signal_processed=zeros(Na,Nr);%处理完的信号
H_az=exp(-im*pi*f_eta.^2/Ka);
for k=1:Nr
    signal_processed(:,k) =ifft( H_az.'.*(Signal_RCMC(:,k))); %方位向压缩后
end
figure;
mesh(r,y,abs(signal_processed));
view(0,90);xlim([27800 28300]);
xlabel('距离向');
ylabel('方位向');
zlabel('幅度'); title('点目标成像结果');