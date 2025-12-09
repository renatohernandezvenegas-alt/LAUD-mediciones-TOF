%% ---------- ADQUISICION DE DATOS PARA MEDICIONES DE TIEMPO DE VUELO ---------- %%
%  Comunicacion con osciloscopo Rigol y  generador de funciones Agilent

clc;
clear all;
close all;

%% Identificar objetos VISA conectados al equipo
visadevlist;

%% ---------- COMUNICACION CON GENERADOR DE FUNCIONES ---------- %%

GEN = visadev("USB0::0x0957::0x0407::MY44022852::0");
           %creamos el objeto cada vez que se corra el programa por primera vez

%% CONFIGURACION DE ELEMENTALES %%

% Abrir conexion
fopen(GEN);

% Identificacion del instrumento
fprintf(GEN, '*IDN?');
id = fscanf(GEN);
disp(['Conectado a: ', id]);

% Estado Burst
fprintf(GEN, 'BURS:STAT OFF');

% Configurar salida en alta impedancia
fprintf(GEN, 'OUTP:LOAD INF');

% Activar salida
fprintf(GEN, 'OUTP ON');

%% CREAR FUNCION ARBITRARIA %%

% PARAMETROS BASICOS DEL PULSO
fs = 5e6;                 % Frecuencia de muestreo para la forma arbitraria (<= 50 MSa/s)
f_seno = 500e3;           % Frecuencia de la señal senoidal
T_total = 1/1000;         % Periodo total 1/frecuencia entre pulsos
N = round(fs * T_total);  % Número de muestras totales
t = (0:N-1)/fs;           % Vector de tiempo

% Número de ciclos activos dentro del pulso
n_ciclos = 5;
duracion_activa = n_ciclos / f_seno;
N_activa = round(fs * duracion_activa);

% Crear un pulso: seno durante N_activa muestras, luego ceros
onda = [sin(2*pi*f_seno*t(1:N_activa)) zeros(1, N-N_activa)];
onda = onda / max(abs(onda));  % Normalizar a ±1

%% ENVIAR FUNCION ARBITRARIA A GENERADOR %%

% El 33220A espera datos enteros de 14 bits (0 a 16383)
onda_dac = round((onda + 1) * (16383/2)); % Escala a rango DAC 0–16383

% Borrar forma previa y cargar nueva
fprintf(GEN, 'DATA:VOL:CLE');
binblockwrite(GEN, onda_dac, 'uint16', 'DATA:DAC ARB2,');
fprintf(GEN, '\n');  % <-- esta línea reemplaza la anterior y evita el error

%% Seleccionar modo arbitrario
fprintf(GEN, 'FUNC:USER ARB2');
fprintf(GEN, 'FUNC USER');

% Configurar frecuencia base para repetición de la forma
fprintf(GEN, 'FREQ 1805');  % Repetición cada 1/1000

% Ajustar amplitud y offset
fprintf(GEN, 'VOLT 0.5');       % 1 Vpp
fprintf(GEN, 'VOLT:OFFS 0');

% Activar salida
fprintf(GEN, 'OUTP ON');

pause(2);

%% CERRAR CONEXIONES CON GENERADOR %%
fclose(GEN);
delete(GEN);

%% -------------- COMUNICACION CON EL OSCILOSCOPIO -------------- %%

% Creamos variable de objeto VISA que queremos controlar
   OSC = visadev("USB0::0x1AB1::0x0488::DS1BA203700099::0::INSTR");
               % creamos el objeto cada vez que se corra el programa por primera vez

%% CONFIGURACION DE ELEMENTALES PARA VISUALIZACION CORRECTA DE ONDA EN OSCIOLOSCOPIO %%
% Alternamos entre RUN o STOP
   writeline(OSC, ':RUN');
   writeline(OSC, ':STOP');

% Boton AUTO en osciloscopio
  writeline(OSC, ':AUTO');

% Escalado de rejillas en osciloscopio
    writeline(OSC, ":ACQ:AVER 64");
    writeline(OSC, ":TIM:SCAL 0.000006");   % escala eje x 10 ms/div
    writeline(OSC, ":CHAN1:OFFS 0");        % offset CHAN1
    writeline(OSC, ":CHAN2:OFFS 0");        % offset CHAN1
    writeline(OSC, ":CHAN1:SCAL 2 ");       % escala eje y

%% ADQUISICION DE DATOS DE AMBOS CANALES %%
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

% NORMALIZACION Y CENTRADO DE SEÑALES

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

%% CALCULOS DE PUNTOS MAXIMOS %%

% CHAN1 (peak de señal emisora)
[max1, idx_max1] = max(env1);
t_max1 = t1(idx_max1);

% CHAN2 (peaks de señal receptora)
[picos2, locs2] = findpeaks(env2,'SortStr','descend');
max2   = picos2(1);  idx2   = locs2(1);  t_max2 = t2(idx2);  % receptor

% REBOTES (comentar seccion si no se visualizan, para evitar errores
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

% Marcadores de peaks
plot(t_max1, max1, 'ko', 'MarkerFaceColor','g');       % max CHAN1 1
plot(t_max2, max2, 'ko', 'MarkerFaceColor','b');       % primer pico C1
plot(t_max3, max3, 'ko', 'MarkerFaceColor','m');       % segundo pico C2 (rebote)
plot(t_max4, max4, 'ko', 'MarkerFaceColor','m')        % tercer pico C3 (2do rebote)

% Etiquetas
xlabel('Tiempo (s)');
ylabel('Voltaje (V)');
title('Señales y Envolventes — Canal 1 (Azul) / Canal 2 (Rojo)');

legend({'Canal 1','Envolvente C1',...
        'Canal 2','Envolvente C2',...
        'Max C1','Máx C2 (receptor)','Máx C2 (rebote)', 'Max C3 (segundo rebote)'});

%% ---------- CALCULAR VELOCIDADES ---------- %%

% Definimos Δx (ancho de muestra a medir)
d = 2e-02;     %(en metros)

% EMISOR - RECEPTOR (Δt entre primeros dos picos)
delta_t1  = t_max2 - t_max1;

% Calculo de Velocidad V = Δx/Δt1
V1        = d / delta_t1;

% RECEPTOR - PRIMER REBOTE (entre segundo y tercer peak)
delta_t2 = (t_max3 - t_max2)/2;    % diferencia de tiempo entre ambos picos
                                  % /2 porque es ida y vuelta

% Calculo de Velocidad V = Δx/Δt2
V2       = d / (delta_t2);

% RECEPTOR - SEGUNDO REBOTE (entre segundo y cuarto peak)
delta_t3 = (t_max4 - t_max2)/4;    % diferencia de tiempo entre ambos picos
                                  % /4 porque es ida y vuelta

% Calculo de Velocidad V = Δx/Δt3
V3       = d / (delta_t3);

%% ---------- IMPRIMIR RESULTADOS EN VENTANA DE COMANDOS ---------- %%

fprintf('Δt  (C2 - C1)               = %.6e s\n', delta_t1);
fprintf('  → Velocidad C1→C2         = %.6f m/s\n', V1);
fprintf('Δt  rebote (C3 - C2)        = %.6e s\n', delta_t2);
fprintf('  → Velocidad rebote        = %.6f m/s\n', V2);
fprintf('Δt  rebote (C4 - C3)        = %.6e s\n', delta_t3);
fprintf('  → Velocidad rebote        = %.6f m/s\n', V3);

%% ---------- GUARDADO DE DATOS EN EXCEL ---------- %%

% Obtener fecha y hora actuales
fechaHora = datetime('now', 'Format', 'yyyyMMdd_HHmmss');

% Modificar segun medicion
material = "MADERA LAUREL";

% Nombre del archivo excel en el que se guardara la info
filename = "Mediciones2909_Transversal.xlsx";

%% Contador de iteraciones

% Verificar si el archivo y la hoja existen
if isfile(filename)
    try
        T_existente = readtable(filename, 'Sheet', sheetName);
        % Contar el número de filas existentes (cada fila = una iteración)
        iteracion = height(T_existente) + 1;
    catch
        % Si la hoja no existe aún
        T_existente = [];
        iteracion = 1;
    end
else
    T_existente = [];
    iteracion = 1;
end

% Preparar datos
datos = {d; delta_t; V; delta_t2; V2; delta_t3; V3};
etiquetas = {'Distancia(m)';'Tiempo1(s)';'Velocidad1(m/s)';...
    'TiempoRebote/2(s)';'Velocidad2 (Rebote)(m/s)';...
    'TiempoRebote/4(s)';'Velocidad3 (Rebote)(m/s)'};

%%Preparar datos actuales
T = table(iteracion, d, delta_t, V, delta_t2, V2, delta_t3, V3, ...
    'VariableNames', {'Iteracion', 'Distancia', 'Tiempo1', 'Velocidad1', ...
                      'TiempoRebote_2', 'Velocidad2', ...
                      'TiempoRebote_4', 'Velocidad3'});

% Guardar cada tipo de material en una hoja separada
sheetName = material;

% Obtener fecha y hora actuales
fechaHora = datetime('now'); % formato datetime, se puede mostrar en Excel directamente

%%Guardar o actualizar hoja existente
if isfile(filename)
try
 T_existente = readtable(filename, 'Sheet', sheetName);
 T_final = [T_existente; T]; % agregar nueva iteración
catch
 T_final = T; % si no existe hoja, crearla
end
else
 T_final = T; % primera iteración
end

%%Guardar tabla en Excel
writetable(T_final, filename, 'Sheet', sheetName);

% Centrar los datos
Excel = actxserver('Excel.Application');
Workbook = Excel.Workbooks.Open(fullfile(pwd, filename));

% Seleccionar la hoja
Sheet = Workbook.Sheets.Item(sheetName);

% Seleccionar todas las celdas usadas
UsedRange = Sheet.UsedRange;

% Centrar horizontal y verticalmente
UsedRange.HorizontalAlignment = -4108;  % xlCenter
UsedRange.VerticalAlignment   = -4108;  % xlCenter

% Guardar cambios y cerrar Excel
Workbook.Save();
Workbook.Close();
Excel.Quit();
Excel.delete();

%% ---------- GUARDAR IMAGEN DE GRAFICO EN CARPETA ---------- %%

carpeta = fullfile(pwd, 'Graficas');   % Carpeta "Graficas" dentro del proyecto
if ~exist(carpeta, 'dir')
    mkdir(carpeta);
end

% Usamos la misma variable "iteracion" que ya está definida en la exportación a Excel
nombreMaterial = regexprep(material,'\s+','_'); % reemplaza espacios por "_"
nombreArchivo = sprintf('Grafica_%s_TR_Iteracion_%d.jpg', nombreMaterial, iteracion);
saveas(gcf, fullfile(carpeta, nombreArchivo));


