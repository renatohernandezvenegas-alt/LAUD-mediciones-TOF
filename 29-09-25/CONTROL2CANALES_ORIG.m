%% ADQUISICION DE DATOS OSCILOSCOPIO RIGOL DS1204B %%
%% COMUNICACION CON EL OSCILOSCOPIO %%
% Identificamos objetos VISA conectados al equipo
% visadevlist
% Borramos la variable de objeto VISA del workspace
% clear OSC;     
% Creamos variable de objeto VISA que queremos controlar
% OSC = visadev("USB0::0x1AB1::0x0488::DS1BA203700099::0::INSTR");
%% CONFIGURACION DE ELEMENTALES PARA VISUALIZACION CORRECTA DE ONDA EN OSCIOLOSCOPIO %%
% Alternamos entre RUN o STOP
   % writeline(OSC, ':RUN');
   % writeline(OSC, ':STOP');
  
% Boton AUTO en osciloscopio
   % writeline(OSC, ':AUTO');
   % writeline(OSC, ":ACQ:AVER 32");
   % writeline(OSC, ":TIM:SCAL 0.000002");   % 10 ms/div
   % writeline(OSC, ":CHAN1:OFFS 0");
   % writeline(OSC, ":CHAN2:OFFS 0");
   % writeline(OSC, ":CHAN1:SCAL 2 ");
   % writeline(OSC, ":CHAN2:SCAL 0.20");
%% ADQUISICION %%
function [t, v] = obtenerCanal(OSC, canal)
   writeline(OSC, sprintf(":WAV:SOUR CHAN%d", canal));
   writeline(OSC, ":WAV:MODE NORM");
   writeline(OSC, ":WAV:FORM BYTE");
   writeline(OSC, ":WAV:POIN 4800");
   writeline(OSC, sprintf(":WAV:YINC? CHAN%d", canal)); yinc = str2double(readline(OSC));
   writeline(OSC, sprintf(":WAV:YOR? CHAN%d", canal));  yor  = str2double(readline(OSC));
   writeline(OSC, sprintf(":WAV:YREF? CHAN%d", canal)); yref = str2double(readline(OSC));
   writeline(OSC, sprintf(":WAV:XINC? CHAN%d", canal)); xinc = str2double(readline(OSC));
   writeline(OSC, sprintf(":WAV:XOR? CHAN%d", canal));  xorigin = str2double(readline(OSC));
   writeline(OSC, ":WAV:DATA?");
   raw = binblockread(OSC, "uint8");
   readline(OSC);
   v = (double(raw) - yref - yor) * yinc;
   t = xorigin + (0:length(v)-1) * xinc;
end
%% LECTURA DE CANALES %%
[t1, v1] = obtenerCanal(OSC, 1);
[t2, v2] = obtenerCanal(OSC, 2);
%% NORMALIZACION Y CENTRADO DE SEÑALES
% Centrar ambas señales en el eje Y = 0
v1 = v1 - mean(v1);
v2 = v2 - mean(v2);
% Normalizamos ambas señales, para que queden a igual escala
v1 = v1 / max(abs(v1));
v2 = v2 / max(abs(v2));
%% CALCULO DE ENVOLVENTE %%
np = 13;
[up1, lo1] = envelope(v1,  np, 'peak');
[up2, lo2] = envelope(v2,  np, 'peak');
env1 = up1; % Graficaremos solo envolvente superior
env2 = up2;
% env1 = (abs(up1) + abs(lo1)) / 2; % Graficaremos solo envolvente superior
% env2 = (abs(up2) + abs(lo2)) / 2;
%% CALCULOS DE PUNTOS MAXIMOS %%
% CHAN1 (pico de señal emisora)
[max1, idx_max1] = max(env1);
t_max1 = t1(idx_max1);
% CHAN2 (picos de señal receptora (con rebotes))
[picos2, locs2] = findpeaks(env2,'SortStr','descend');
max2   = picos2(1);  idx2   = locs2(1);  t_max2 = t2(idx2);  % receptor
max3   = picos2(2);  idx3   = locs2(2);  t_max3 = t2(idx3);  % primer rebote
max4   = picos2(3);  idx4   = locs2(3);  t_max4 = t2(idx4);  % segundo rebote
%% GRAFICAS %%
figure;
hold on; grid on;
% Señal emisora
plot(t1, v1,   'b',  'LineWidth',1.2);
% Envolvente señal emisora
plot(t1, env1,  'Color',[0.9 0.4 0.1],'LineWidth',1.5);
% Señal receptora
plot(t2, v2, 'r', 'LineWidth',1.2);
% Envolvente señal receptora
plot(t2, env2,  'Color',[0 0.4 0],'LineWidth',1.5);
% Marcadores
plot(t_max1, max1, 'ko', 'MarkerFaceColor','g');         % max CHAN1 1
plot(t_max2, max2, 'ko', 'MarkerFaceColor','b');         % primer pico C1
plot(t_max3, max3, 'ko', 'MarkerFaceColor','m');         % segundo pico C2 (rebote)
plot(t_max4, max4, 'ko', 'MarkerFaceColor','m');         % tercer pico C3 (2do rebote)
% Etiquetas
xlabel('Tiempo (s)');
ylabel('Voltaje (V)');
title('Señales y Envolventes — Canal 1 (Azul) / Canal 2 (Rojo)');
legend({'Canal 1','Envolvente C1',...
       'Canal 2','Envolvente C2',...
       'Max C1','Máx C2 (receptor)','Máx C2 (rebote)', 'Max C3 (segundo rebote)'});
%% CALCULOS DE VELOCIDADES %%
% Definimos Δx (ancho de probeta)
d = 8.8e-03;
% EMISOR RECEPTOR
% Δt entre primeros dos picos
delta_t  = t_max2 - t_max1;
% Calculo de Velocidad V = Δx/Δt
V        = d / delta_t;
% RECEPTOR - PRIMER REBOTE
% Rebote (receptor-receptor)
delta_t1 = t_max3 - t_max2;    % diferencia de tiempo entre ambos picos
delta_t2 = delta_t1/2;   % /2 porque es ida y vuelta
% Calculo de Velocidad V = Δx/Δt
V2       = d / (delta_t2);  
% Segundo rebote (receptor-receptor)
delta_t1 = t_max4 - t_max2;    % diferencia de tiempo entre ambos picos
delta_t3 = delta_t1/4;  % /4 porque es ida y vuelta
% Calculo de Velocidad V = Δx/Δt
V3       = d / (delta_t3);  
fprintf('Δt  (C2 - C1)               = %.6e s\n', delta_t);
fprintf('  → Velocidad C1→C2         = %.6f m/s\n', V);
fprintf('Δt  rebote (C3 - C2)        = %.6e s\n', delta_t2);
fprintf('  → Velocidad rebote        = %.6f m/s\n', V2);
fprintf('Δt  rebote (C4 - C3)        = %.6e s\n', delta_t3);
fprintf('  → Velocidad rebote        = %.6f m/s\n', V3);
%% GUARDADO DE DATOS %%
% Modificar segun medicion
material = "ALUMINIO";
% Nombre del archivo excel en el que se guardara la info
filename = "Mediciones.xlsx";
% EXPORTACION A EXCEL
datos = {d; delta_t; V; delta_t2; V2; delta_t3; V3};
etiquetas = {'Distancia';'Tiempo1';'Velocidad1';...
   'TiempoRebote/2';'Velocidad2 (Rebote)';...
   'TiempoRebote/4';'Velocidad3 (Rebote)'};
if isfile(filename)
   A = readcell(filename);
   numCols = size(A,2) - 1;
   header = {['Iteracion' num2str(numCols + 1)]};
   nuevaCol = [header; datos];
   A = [A, nuevaCol];
else
   A = [{'Variables', 'Iteracion1'}; [etiquetas, datos]];
end
writecell(A, filename);
%% GUARDAR IMAGEN DE GRAFICO EN CARPETA
iteracion = size(readcell('Mediciones'),2) - 1;
nombreArchivo = sprintf('Grafica_Iteracion_%d.png', iteracion);
saveas(gcf, nombreArchivo);


