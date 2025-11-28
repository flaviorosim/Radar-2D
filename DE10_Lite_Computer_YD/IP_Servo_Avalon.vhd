library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Controlador de Servo com Interface Avalon-MM
-- Permite que o Nios II escreva a posição (0-255) em um registrador.

entity IP_Servo_Avalon is
    port (
        -- Sinais Globais
        clk        : in  std_logic;
        reset_n    : in  std_logic; -- Atenção: Avalon usa reset_n (ativo baixo)

        -- Interface Avalon-MM Slave (Escrita)
        chipselect : in  std_logic;
        write_n    : in  std_logic; -- '0' indica escrita
        writedata  : in  std_logic_vector(31 downto 0); -- Dados vindos do Nios

        -- Interface Externa (Conduit)
        commande   : out std_logic
    );
end entity IP_Servo_Avalon;

architecture Behavioral of IP_Servo_Avalon is

    -- Mesmas constantes do teste standalone (50MHz)
    constant CLK_FREQ       : integer := 50000000;
    constant PWM_FREQ       : integer := 50; 
    constant PERIOD_CYCLES  : integer := CLK_FREQ / PWM_FREQ; -- 1.000.000

    -- Range Estendido (0.5ms a 2.5ms)
    constant MIN_PULSE_CYCLES : integer := 25000;   
    constant CYCLES_PER_STEP  : integer := 392;

    -- Registrador interno para guardar a posição
    signal reg_position : std_logic_vector(7 downto 0) := (others => '0');

    -- Sinais do PWM
    signal pwm_counter : integer range 0 to PERIOD_CYCLES := 0;
    signal high_time   : integer range 0 to PERIOD_CYCLES := 0;

begin

    -- Calcula o tempo em nível alto baseado no valor do registrador
    high_time <= MIN_PULSE_CYCLES + (to_integer(unsigned(reg_position)) * CYCLES_PER_STEP);

    -- ========================================================================
    -- PROCESSO 1: Interface Avalon (Escrita)
    -- ========================================================================
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            reg_position <= (others => '0'); -- Posição inicial 0
        elsif rising_edge(clk) then
            -- Se o processador selecionou este IP e mandou escrever (write_n = 0)
            if chipselect = '1' and write_n = '0' then
                -- Pega apenas os 8 bits menos significativos do dado de 32 bits
                reg_position <= writedata(7 downto 0);
            end if;
        end if;
    end process;

    -- ========================================================================
    -- PROCESSO 2: Gerador PWM (Igual ao Standalone)
    -- ========================================================================
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            pwm_counter <= 0;
            commande    <= '0';
        elsif rising_edge(clk) then
            -- Contador principal
            if pwm_counter < PERIOD_CYCLES - 1 then
                pwm_counter <= pwm_counter + 1;
            else
                pwm_counter <= 0;
            end if;

            -- Comparador
            if pwm_counter < high_time then
                commande <= '1';
            else
                commande <= '0';
            end if;
        end if;
    end process;

end architecture Behavioral;