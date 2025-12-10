%% ===================================================================== %%
%          MEDICION DE CONSTANTE ELASTICA MEDIANTE TECNICA DE VUELO
%          Laboratorio de Acústica musical Lutheria Postdigital LAÚD
%% ===================================================================== %%
%
%
% 
% https://github.com/renatohernandezvenegas-alt/LAUD-mediciones-TOF/tree/main

%% INICIALIZACION DE VARIABLES Y PRESENTACION DE PROGRAMA %%clc; clear; close all;
fechaHora = datetime('now', 'Format', 'yyyyMMdd_HHmmss'); % Obtener fecha y hora actuales
disp('======    Medicion de velocidad de propagacion en distintos materiales utilizando "TOF"   ======');
disp('======    Velocidad de propagacion de ondas longitudinales, transversales o radiales      ======');
disp('');

%%------------------------------------DISTANCIA ------------------------------------------%%
d = input('\n Ingrese el ancho del material a medir [ej. 3(cm) = 0.03(m)]: '); %Ancho de la probeta 

%%------------------------------------ MATERIALIDAD ------------------------------------------%%
fprintf('\n Materiales recurrentes: \n ACERO\n LATON\n COBRE\n ALUMINIO\n LAUREL\n CIRUELILLO \n EBANO\n NOGAL\n'); 
opcion = input('Ingrese la naturaleza del material a medir: ', 's');  % 's' hace que sea texto
material = opcion;
masa = input('Ingrese la masa del material a medir en (Kg): ');
dimension_x = input('Ingrese el largo del material a medir en (m): ');
dimension_y = input('Ingrese el ancho del material a medir en (m): ');
dimension_z = input('Ingrese el alto (espesor) del material a medir en (m): ');





                                %% VARIABLES GENERALES DE MEDICION 
% Si se desea saltar la inicializacion de los pasos anteriores, apretar Run to End desde esta seccion

%%-------------------------------- TIPO DE MEDICION --------------------------------------%%
opcionMedicion = 0;            
while ~ismember(opcionMedicion, [1 2 3])
    disp('Seleccione el tipo de medición:');
    disp('1 = Longitudinal');
    disp('2 = Transversal');
    disp('3 = Radial');
    opcionMedicion = input('Ingrese el número correspondiente (1-3): ');
end
if opcionMedicion == 1
    tipoMedicion = 'Longitudinal'; elseif opcionMedicion == 2
    tipoMedicion = 'Transversal'; else
    tipoMedicion = 'Radial'; end

%%-------------------------------------- RESUMEN ------------------------------------------%%
disp(' '); disp('=== Resumen de datos ingresados ===');
fprintf('Valor de d: %.4f m\n', d);
fprintf('Material elegido: %s\n', material);
fprintf('Archivo Excel: %s\n', filename);
fprintf('Archivo Excel guardado en:\n%s\n', rutaCompleta); disp('===================================');

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
 %   writeline(OSC, ":ACQ:AVER 64");
 %   writeline(OSC, ":TIM:SCAL 0.000006");   % 10 ms/div
 %   writeline(OSC, ":CHAN1:OFFS 0");
 %   writeline(OSC, ":CHAN2:OFFS 0");
 %   writeline(OSC, ":CHAN1:SCAL 2 ");

%% ADQUISICION DE DATOS %%
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

%% LECTURA DE CANALES DEL OSCILOSCOPIO %%
[t1, v1] = obtenerCanal(OSC, 1);
[t2, v2] = obtenerCanal(OSC, 2);

%% NORMALIZACION Y CENTRADO DE SEÑALES %%
v1 = v1 - mean(v1);
v2 = v2 - mean(v2);

v1 = v1 / max(abs(v1));
v2 = v2 / max(abs(v2));

%% CALCULO DE ENVOLVENTE %%
np = 13;
[up1, lo1] = envelope(v1,  np, 'peak');
[up2, lo2] = envelope(v2,  np, 'peak');

env1 = up1;
env2 = up2;

%% CALCULOS DE PUNTOS MAXIMOS %%
[max1, idx_max1] = max(env1);
t_max1 = t1(idx_max1);

[picos2, locs2] = findpeaks(env2,'SortStr','descend');
max2   = picos2(1);  idx2   = locs2(1);  t_max2 = t2(idx2);
max3   = picos2(2);  idx3   = locs2(2);  t_max3 = t2(idx3);
max4   = picos2(3);  idx4   = locs2(3);  t_max4 = t2(idx4);

%% GRAFICAS %%
figure;
hold on; grid on;

plot(t1, v1,   'b',  'LineWidth',1.2);
plot(t1, env1,  'Color',[0.9 0.4 0.1],'LineWidth',1.5);

plot(t2, v2, 'r', 'LineWidth',1.2);
plot(t2, env2,  'Color',[0 0.4 0],'LineWidth',1.5);

plot(t_max1, max1, 'ko', 'MarkerFaceColor','g');         
plot(t_max2, max2, 'ko', 'MarkerFaceColor','b');
plot(t_max3, max3, 'ko', 'MarkerFaceColor','m');
plot(t_max4, max4, 'ko', 'MarkerFaceColor','m');

xlabel('Tiempo (s)');
ylabel('Voltaje (V)');
title('Señales y Envolventes — Canal 1 (Azul) / Canal 2 (Rojo)');

legend({'Canal 1','Envolvente C1',...
        'Canal 2','Envolvente C2',...
        'Max C1','Máx C2 (receptor)','Máx C2 (rebote)', 'Max C3 (segundo rebote)'});

%% CALCULOS DE VELOCIDADES %%
d = dimension_z;
delta_t  = t_max2 - t_max1;
V        = d / delta_t;

% Segundo rebote
delta_t1 = t_max4 - t_max2;
delta_t3 = delta_t1/4;

% Calculo de Velocidad V = Δx/Δt
V3       = d / (delta_t3);
fprintf('Δt  (C2 - C1) = %.6e s\n', delta_t);fprintf(' Velocidad C1→C2 = %.6f m/s\n', V);fprintf('Δt  rebote (C4 - C3) = %.6e s\n', delta_t3);fprintf('  → Velocidad rebote = %.6f m/s\n', V3);

%% CALCULO DE CONSTANTE ELASTICA
volumen_fisico = dimension_x * dimension_y * dimension_z;
densidad = masa / volumen_fisico; %(kg/m^3)

switch opcionMedicion
    case 1  % Longitudinal
        constante_elastica = densidad * V^2;
        nombreConstante = "EL (Longitudinal)";
    case 2  % Transversal
        constante_elastica = densidad * V^2;
        nombreConstante = "Et (Transversal)";
    case 3  % Radial
        constante_elastica = densidad * V^2;
        nombreConstante = "Er (Radial)";
end

fprintf('\n=== Constante Elástica ===\n');
fprintf('\nConstante elástica (%s): %.3e Pa\n', nombreConstante, constante_elastica);


%% CALCULAR ITERACION CORRECTAMENTE %%
sheetName = 'Registro';
if isfile(filename)
    try
        T_existente = readtable(filename, 'Sheet', sheetName);
        iteracion = height(T_existente) + 1;
    catch
        iteracion = 1;
    end
    else
    iteracion = 1; end

%% ======================= GUARDADO DE DATOS EN EXCEL ======================= %%

%%DATOS
datos = {d; delta_t; V; delta_t3; V3};
etiquetas = {'Distancia(m)';'Tiempo1(s)';'Velocidad1(m/s)';'TiempoRebote/4(s)';'Velocidad3 (Rebote)(m/s)'};
T = table(iteracion, d, delta_t, V, delta_t3, V3, densidad, constante_elastica, ...
    'VariableNames', {'Iteracion','Distancia','Tiempo1','Velocidad1','TiempoRebote_4','Velocidad3','Densidad','ConstanteElastica'});

if exist('T_existente','var')
    T_final = [T_existente; T];
else
    T_final = T;
end

%%GUARDAR EXCEL

filename = ['registro_' material '_' tipoMedicion '_' char(fechaHora) '.xlsx']; % Generar nombre de archivo
directorioActual = pwd;                              %Carpeta para guardar archivos Excel  Directorio del script
carpetaExcel = fullfile(directorioActual, 'archivos-excel');
if ~exist(carpetaExcel, 'dir') % Crear carpeta si no existe
    mkdir(carpetaExcel);
end
rutaCompleta = fullfile(carpetaExcel, filename);    % Ruta completa del archivo
%%writetable(T_final, filename, 'Sheet', sheetName);

fprintf('\n===== Registro actualizado correctamente =====\n');
fprintf('Archivo: %s\n', filename);
fprintf('Iteración guardada: %d\n', iteracion);
fprintf('Constante elástica registrada: %.3e Pa\n', constante_elastica);


if isfile(filename)
    try
        T_existente = readtable(filename, 'Sheet', sheetName);
        T_final = [T_existente; T];
    catch
        T_final = T;
    end
else
    T_final = T;
end

writetable(T_final, filename, 'Sheet', sheetName);

Excel = actxserver('Excel.Application');
Workbook = Excel.Workbooks.Open(fullfile(pwd, filename));
Sheet = Workbook.Sheets.Item(sheetName);
UsedRange = Sheet.UsedRange;
UsedRange.HorizontalAlignment = -4108;
UsedRange.VerticalAlignment   = -4108;
Workbook.Save();
Workbook.Close();
Excel.Quit();
Excel.delete();

%% GUARDAR IMAGEN DE GRAFICO %%
carpeta = fullfile(pwd, 'Graficas');   
if ~exist(carpeta, 'dir')
    mkdir(carpeta);
end

nombreMaterial = regexprep(material,'\s+','_');
nombreArchivo = sprintf('Grafica_%s_TR_Iteracion_%d.jpg', nombreMaterial, iteracion);
saveas(gcf, fullfile(carpeta, nombreArchivo));

