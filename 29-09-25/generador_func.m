clc;
clear all;
close all; 


fgen = visadev("USB0::0x0957::0x0407::MY44022852::0"); %%(Agilent Technologies,33220A,MY44022852,2.07-2.02-22-2)

 
 
 % Crear objeto VISA-USB (revisa el ID del dispositivo en MATLAB -> "instrhwinfo('visa')") 
%fgen = visa('AGILENT', 'USB0::0x0957::0x0407::MY44012345::INSTR'); % <-- cambia por tu ID

% Abrir conexión
fopen(fgen);

% Identificación del instrumento
fprintf(fgen, '*IDN?');
id = fscanf(fgen);
disp(['Conectado a: ', id]);

%Estado Burst
fprintf(fgen, 'BURS:STAT OFF');

% Configurar salida en alta impedancia
fprintf(fgen, 'OUTP:LOAD INF');  

% Activar salida
fprintf(fgen, 'OUTP ON');


%% --- Parámetros del pulso ---
fs = 5e6;           % Frecuencia de muestreo para la forma arbitraria (<= 50 MSa/s)
f_seno = 500e3;     % Frecuencia de la señal senoidal
T_total = 1/1000;    % Periodo total 1/frecuencia entre pulsos
N = round(fs * T_total);  % Número de muestras totales
t = (0:N-1)/fs;     % Vector de tiempo

% Número de ciclos activos dentro del pulso
n_ciclos = 5;
duracion_activa = n_ciclos / f_seno;
N_activa = round(fs * duracion_activa);


% Crear un pulso: seno durante N_activa muestras, luego ceros
onda = [sin(2*pi*f_seno*t(1:N_activa)) zeros(1, N-N_activa)];
onda = onda / max(abs(onda));  % Normalizar a ±1

%% --- Enviar forma de onda al generador ---
% El 33220A espera datos enteros de 14 bits (0 a 16383)
onda_dac = round((onda + 1) * (16383/2)); % Escala a rango DAC 0–16383

% Borrar forma previa y cargar nueva
 fprintf(fgen, 'DATA:VOL:CLE');
binblockwrite(fgen, onda_dac, 'uint16', 'DATA:DAC ARB2,');
fprintf(fgen, '\n');  % <-- esta línea reemplaza la anterior y evita el error

%% Seleccionar modo arbitrario%%
fprintf(fgen, 'FUNC:USER ARB2');
fprintf(fgen, 'FUNC USER');

% Configurar frecuencia base para repetición de la forma
fprintf(fgen, 'FREQ 1805');  % Repetición cada 1/1000

% Ajustar amplitud y offset
fprintf(fgen, 'VOLT 0.5');       % 1 Vpp
fprintf(fgen, 'VOLT:OFFS 0');

% Activar salida
fprintf(fgen, 'OUTP ON');

pause(2);

%% dd
% Apagar salida y cerrar

fclose(fgen);
delete(fgen);

disp('Prueba de conexión completada correctamente.');
