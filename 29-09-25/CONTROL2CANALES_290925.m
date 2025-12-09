%% ADQUISICION DE DATOS OSCILOSCOPIO RIGOL DS1204B %%

%programa sin rebotes
%% COMUNICACION CON EL OSCILOSCOPIO %%

% Identificamos objetos VISA conectados al equipo
  % visadevlist;
% Borramos la variable de objeto VISA del workspace
  % clear OSC;      
% Creamos variable de objeto VISA que queremos controlar
  %  OSC = visadev("USB0::0x1AB1::0x0488::DS1BA203700099::0::INSTR"); %%Se debe activar cada vez que se inicie el programa por primera vez
    

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
  %   writeline(OSC, ":CHAN1:SCAL 2 ");

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
% max3   = picos2(2);  idx3   = locs2(2);  t_max3 = t2(idx3);  % primer rebote
% max4   = picos2(3);  idx4   = locs2(3);  t_max4 = t2(idx4);  % segundo rebote
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
%plot(t_max3, max3, 'ko', 'MarkerFaceColor','m');         % segundo pico C2 (rebote)
%plot(t_max4, max4, 'ko', 'MarkerFaceColor','m');         % tercer pico C3 (2do rebote)

% Etiquetas
xlabel('Tiempo (s)');
ylabel('Voltaje (V)');
title('Señales y Envolventes — Canal 1 (Azul) / Canal 2 (Rojo)');

legend({'Canal 1','Envolvente C1',...
        'Canal 2','Envolvente C2',...
        'Max C1','Máx C2 (receptor)','Máx C2 (rebote)', 'Max C3 (segundo rebote)'});

%% CALCULOS DE VELOCIDADES %%
% Definimos Δx (ancho de probeta)
d = 30e-03;     %(metros)

% EMISOR RECEPTOR  Δt entre primeros dos picos
delta_t  = t_max2 - t_max1;

% Calculo de Velocidad V = Δx/Δt
V        = d / delta_t;

% RECEPTOR - PRIMER REBOTE
% Rebote (receptor-receptor)
 % delta_t1 = t_max3 - t_max2;    % diferencia de tiempo entre ambos picos
 % delta_t2 = delta_t1/2;         % /2 porque es ida y vuelta

% Calculo de Velocidad V = Δx/Δt
% V2       = d / (delta_t2);   

% Segundo rebote (receptor-receptor)
% delta_t1 = t_max4 - t_max2;    % diferencia de tiempo entre ambos picos
% delta_t3 = delta_t1/4;         % /4 porque es ida y vuelta

% Calculo de Velocidad V = Δx/Δt
 %V3       = d / (delta_t3);   

fprintf('Δt  (C2 - C1)               = %.6e s\n', delta_t);
fprintf('  → Velocidad C1→C2         = %.6f m/s\n', V);
%fprintf('Δt  rebote (C3 - C2)        = %.6e s\n', delta_t2);
%fprintf('  → Velocidad rebote        = %.6f m/s\n', V2);
%fprintf('Δt  rebote (C4 - C3)        = %.6e s\n', delta_t3);
%fprintf('  → Velocidad rebote        = %.6f m/s\n', V3);

%% GUARDADO DE DATOS %%
% Obtener fecha y hora actuales
fechaHora = datetime('now', 'Format', 'yyyyMMdd_HHmmss');

% Modificar segun medicion
material = "MATERIAL DE IMPRESION AZUL R";

% Nombre del archivo excel en el que se guardara la info
filename = "Mediciones2909_Transversal.xlsx";

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

%% GUARDAR IMAGEN DE GRAFICO EN CARPETA
%%iteracion = size(readcell('Mediciones.xlsx'),2) - 1;

carpeta = fullfile(pwd, 'Graficas');   % Carpeta "Graficas" dentro del proyecto
if ~exist(carpeta, 'dir')
    mkdir(carpeta);
end

% Usamos la misma variable "iteracion" que ya está definida en la exportación a Excel
nombreMaterial = regexprep(material,'\s+','_'); % reemplaza espacios por "_"
nombreArchivo = sprintf('Grafica_%s_TR_Iteracion_%d.jpg', nombreMaterial, iteracion);
saveas(gcf, fullfile(carpeta, nombreArchivo));


















%% ACTIVIDADES
%Actividades lunes 08 sept
%1. Generar tablas en el guardado de datos de excel -- Por completar
%2. Guardado de tablas en cada hoja de excel para cada tipo de material de
%probeta -- COMPLETADO
%3. Comprender y comentar las funciones del codigo -- FALTA
%4. Calculo de promedio y desviacion estandar para cada iteracion: 
% - distancia (ancho de probeta)
% - velocidad 

%Actividades por hacer
%%Hay un error en el nombre de la iteracion entre excel y el nombre de la foto 
%3. Comprender y comentar las funciones del codigo -- FALTA
%4. Calculo de promedio y desviacion estandar para cada iteracion: 
% - distancia (ancho de probeta)
% - velocidad 

%Actividades lunes 22 sept
%1. Medición de constante elástica longitudinal y radial para cubo de
%prueba de material de impresión 3D azul

%Actividades por hacer
%%Hay un error en el nombre de la iteracion entre excel y el nombre de la foto 
%3. Comprender y comentar las funciones del codigo -- FALTA
%4. Calculo de promedio y desviacion estandar para cada iteracion: 
% - distancia (ancho de probeta)
% - velocidad 

% Una foto con nombre de iteracion para cada iteracion
