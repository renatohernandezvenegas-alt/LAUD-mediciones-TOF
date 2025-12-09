%% ADQUISICION DE DATOS OSCILOSCOPIO RIGOL DS1204B %%

%%PROGRAMA SIN REBOTES

%% SCRIPT INICIO DEL PROGRAMA %%
clc; clear; close all;
fechaHora = datetime('now', 'Format', 'yyyyMMdd_HHmmss'); % Obtener fecha y hora actuales
disp('======    Medicion de velocidad de propagacion en distintos materiales utilizando "TOF"   ======');
disp('======    Velocidad de propagacion de ondas longitudinales, transversales o radiales      ======');
disp('');

d = input('\n Ingrese el valor de d en metros [3(cm) = 0.03(m)]: '); %Ancho de la probeta

% Selección del tipo de medición
opcionMedicion = 0;
while ~ismember(opcionMedicion, [1 2 3])
    disp('Seleccione el tipo de medición:');
    disp('1 = Longitudinal');
    disp('2 = Transversal');
    disp('3 = Radial');
    opcionMedicion = input('Ingrese el número correspondiente (1-3): ');
end
if opcionMedicion == 1
    tipoMedicion = 'Longitudinal';
elseif opcionMedicion == 2
    tipoMedicion = 'Transversal';
else
    tipoMedicion = 'Radial';
end

%MATERIALIDAD
fprintf('\n Materiales recurrentes: \n ACERO\n LATON\n COBRE\n ALUMINIO\n LAUREL\n CIRUELILLO \n EBANO\n NOGAL\n'); 
opcion = input('Ingrese la naturaleza del material a medir: ', 's');  % <-- 's' hace que sea texto
material = opcion;

%%Archivo excel
filename = ['registro_' material '_' tipoMedicion '_' char(fechaHora) '.xlsx']; % Generar nombre de archivo
directorioActual = pwd;                              % % Carpeta para guardar archivos Excel  Directorio del script
carpetaExcel = fullfile(directorioActual, 'ARCHIVOS EXCEL');
if ~exist(carpetaExcel, 'dir') % Crear carpeta si no existe
    mkdir(carpetaExcel);
end
rutaCompleta = fullfile(carpetaExcel, filename);    % Ruta completa del archivo

disp(' ');                                          %RESUMEN DE INICIALIZACION
disp('=== Resumen de datos ingresados ===');
fprintf('Valor de d: %.4f m\n', d);
fprintf('Material elegido: %s\n', material);
fprintf('Archivo Excel: %s\n', filename);
fprintf('Archivo Excel guardado en:\n%s\n', rutaCompleta);
disp('===================================');

%% COMUNICACION CON EL OSCILOSCOPIO %%

% Identificamos objetos VISA conectados al equipo
  visadevlist;
% Borramos la variable de objeto VISA del workspace
  clear OSC;      
% Creamos variable de objeto VISA que queremos controlar
  OSC = visadev("USB0::0x1AB1::0x0488::DS1BA203700099::0::INSTR"); %%Se debe activar cada vez que se inicie el programa por primera vez

%% CONFIGURACION DE ELEMENTALES PARA VISUALIZACION CORRECTA DE ONDA EN OSCIOLOSCOPIO %%
% Alternamos entre RUN o STOP 
 % writeline(OSC, ':RUN');
  % writeline(OSC, ':STOP');
% Boton AUTO en osciloscopio
  writeline(OSC, ':AUTO');

% Escalado de rejillas en osciloscopio
   writeline(OSC, ":ACQ:AVER 64");
   writeline(OSC, ":TIM:SCAL 0.000006");   % 10 ms/div
   writeline(OSC, ":CHAN1:OFFS 0");
   writeline(OSC, ":CHAN2:OFFS 0");
  %writeline(OSC, ":CHAN1:SCAL 2 ");


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

% CHAN2 (pico de señal receptora (sin rebote) )
[picos2, locs2] = findpeaks(env2,'SortStr','descend');
max2   = picos2(1);  
idx2   = locs2(1);  
t_max2 = t2(idx2);  

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

% Etiquetas
xlabel('Tiempo (s)');
ylabel('Voltaje (V)');
title('Señales y Envolventes — Canal 1 (Azul) / Canal 2 (Rojo)');

legend({'Canal 1','Envolvente C1',...
        'Canal 2','Envolvente C2',...
        'Max C1','Máx C2 (receptor)','Máx C2 (rebote)', 'Max C3 (segundo rebote)'});

%% CALCULOS DE VELOCIDADES %%
% Definimos Δx (ancho de probeta)
d = input('Ingrese el valor del ancho del material (en metros): ');
fprintf('El material elegido es: %s\n', material);

% EMISOR RECEPTOR  Δt entre primeros dos picos
delta_t  = t_max2 - t_max1;

% Calculo de Velocidad V = Δx/Δt
V        = d / delta_t;

fprintf('Δt  (C2 - C1)               = %.6e s\n', delta_t);
fprintf('  → Velocidad C1→C2         = %.6f m/s\n', V);


%% EXPORTACION A EXCEL
%%Contador de iteraciones
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

%preparar datos
datos = {d; delta_t; V};
etiquetas = {'Distancia(m)';'Tiempo1(s)';'Velocidad1(m/s)'};

%%Preparar datos actuales
T = table(iteracion, d, delta_t, V, delta_t2, V2, delta_t3, V3, ...
    'VariableNames', {'Iteracion', 'Distancia', 'Tiempo1', 'Velocidad1'});

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

%% GRAFICOS
carpeta = fullfile(pwd, 'Graficos');   % Carpeta "Graficas" dentro del proyecto
if ~exist(carpeta, 'dir')
    mkdir(carpeta);
end

% Usamos la misma variable "iteracion" que ya está definida en la exportación a Excel
nombreMaterial = regexprep(material,'\s+','_'); % reemplaza espacios por "_"
nombreArchivo = sprintf('Grafica_%s_TR_Iteracion_%d.jpg', nombreMaterial, iteracion);
saveas(gcf, fullfile(carpeta, nombreArchivo));

















