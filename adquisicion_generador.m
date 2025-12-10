%% ===================================================================== %%
%     ADQUISICIÓN DE DATOS - GENERADOR DE FUNCIONES PARA TRANSDUCTOR
%                     Olympus V106 (2.25 MHz)
%                  Excitación arbitraria tipo burst
%                  Compatible con Rigol DS1054Z
%% ===================================================================== %%

clc; clear; close all;

%% --------------------- CONFIGURAR GENERADOR 33220A -------------------- %%
GEN = visadev("USB0::0x0957::0x0407::MY44022852::0");

% Identificacion
writeline(GEN, "*IDN?");
disp("Conectado a: " + readline(GEN));

% Desactivar modos previos
writeline(GEN, "OUTP OFF");
writeline(GEN, "BURS:STAT OFF");
writeline(GEN, "OUTP:LOAD INF");   % Alta impedancia


%% ======================= PARAMETROS DEL TRANSDUCTOR ==================== %%
f_res = 2.25e6;        % Frecuencia de resonancia Olympus V106 (2.25 MHz)
n_ciclos = 5;          % Burst recomendado para TOF
fs = 20e6;             % Frecuencia de muestreo para ARB (máximo permitido por el 33220A)

% Periodo de repetición del burst
f_repeticion = 1000;   % 1 kHz
T_total = 1 / f_repeticion;

% Número total de muestras
N_total = round(fs * T_total);
t = (0:N_total - 1) / fs;

% Duración activa del burst
T_activa = n_ciclos / f_res;
N_activa = round(T_activa * fs);

%% ------------------------- CREACIÓN DEL BURST -------------------------- %%
% Seno de 2.25 MHz durante N_activa muestras + ceros
onda = [sin(2*pi*f_res*t(1:N_activa)), zeros(1, N_total - N_activa)];

% Normalizar a ±1
onda = onda / max(abs(onda));

% Pasar a rango del DAC del 33220A (14 bits)
onda_dac = uint16( (onda + 1) * (16383/2) );


%% ------------------------ CARGAR FORMA ARBITRARIA ---------------------- %%
writeline(GEN, "DATA:VOL:CLE");       % borrar ARB previa
binblockwrite(GEN, onda_dac, "uint16", "DATA:DAC ARB1,");
writeline(GEN, "");                   % terminar comando


%% ---------------------- CONFIGURAR MODO ARBITRARIO ---------------------- %%
writeline(GEN, "FUNC:USER ARB1");
writeline(GEN, "FUNC USER");

% Repetición del burst
writeline(GEN, sprintf("FREQ %f", f_repeticion));

% Amplitud de salida (ajustable)
writeline(GEN, "VOLT 1");          % 1 Vpp – puedes subir/bajar según necesidad
writeline(GEN, "VOLT:OFFS 0");

% Activar salida
writeline(GEN, "OUTP ON");

disp("Pulso de 2.25 MHz enviado correctamente al generador.");
pause(1);


%% ------------------ COMUNICACION CON OSCILOSCOPIO ----------------------- %%
OSC = visadev("USB0::0x1AB1::0x0488::DS1BA203700099::0::INSTR");

% Configuración básica
writeline(OSC, ':RUN');
writeline(OSC, ':AUTO');

writeline(OSC, ":ACQ:AVER 64");
writeline(OSC, ":TIM:SCAL 0.0000002");  % 200 ns/div → adecuado para 2.25 MHz
writeline(OSC, ":CHAN1:SCAL 1");
writeline(OSC, ":CHAN2:SCAL 1");


%% ===================== FUNCIÓN PARA LEER CANALES ======================= %%
function [t, v] = obtenerCanal(OSC, canal)
    writeline(OSC, sprintf(":WAV:SOUR CHAN%d", canal));
    writeline(OSC, ":WAV:MODE NORM");
    writeline(OSC, ":WAV:FORM BYTE");
    writeline(OSC, ":WAV:POIN 4800");

    writeline(OSC, sprintf(":WAV:YINC? CHAN%d", canal)); yinc = str2double(readline(OSC));
    writeline(OSC, sprintf(":WAV:YOR? CHAN%d", canal));  yor  = str2double(readline(OSC));
    writeline(OSC, sprintf(":WAV:YREF? CHAN%d", canal)); yref = str2double(readline(OSC));
    writeline(OSC, sprintf(":WAV:XINC? CHAN%d", canal)); xinc = str2double(readline(OSC));
    writeline(OSC, sprintf(":WAV:XOR? CHAN%d", canal));  x0   = str2double(readline(OSC));

    writeline(OSC, ":WAV:DATA?");
    raw = binblockread(OSC, "uint8");
    readline(OSC);

    v = (double(raw) - yref - yor) * yinc;
    t = x0 + (0:length(v)-1) * xinc;
end