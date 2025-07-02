function PHE_v1
%{
This program will command the arduino directly (without Serial
Communication). 
Functions include:
1)Plotting data from the Arduino
2)Switch on both pumps for easy operation,
3)Save Data that was collected
%}
%% Initial Set-up and Global Variables
%{
This section sets up the arduino. There is no need to use the Arduino IDE
interface for this experiment.
%}
fclose('all');
close all
clc

channel=inputdlg('Arduino Port (i.e. COM7)','Port',1,{'COM7'});
a=arduino(char(channel),'Uno','Libraries','PaulStoffregen/OneWire');
sensors=addon(a,'PaulStoffregen/OneWire','D7');
L=length(sensors.AvailableAddresses);
reset(sensors);
for i=1:L
    write(sensors,sensors.AvailableAddresses{i},hex2dec('44'),true);
end
pause(1);

%From the main power switch, D12 is the first switch and D11 is the second switch
pump={'D12','D11'};
configurePin(a,pump{1},'DigitalOutput');
configurePin(a,pump{2},'DigitalOutput');
configurePin(a,'D9','pullup');
configurePin(a,'D8','pullup');
writeDigitalPin(a,pump{1},0);
writeDigitalPin(a,pump{2},0);

Exit= false;
temp=zeros(L,1);
savetime=1/60;

% Calibration data (2nd OrderPolynomial Fit: Ax^2+Bx+C)
A=[1E-7; -2E-7; -5E-7; -5E-8];
B=[0.0634; 0.0640; 0.0641; 0.0638];
C=[-0.3823; -1.4432; -1.1282; -0.5224];
OFFSET = [0; 0; 0; 0];%[-0.5799;-1.37082;-1.19718;-1.74867];

%% Creating Window and Title
f=figure('Visible','off','Position', [360 300 650 485],...
    'Name','Plate Heat Exchanger', 'NumberTitle','off',...
    'MenuBar','none');
htitle=uicontrol('Style','Text',...
    'String','CENG 176: Plate Heat Exchanger',...
    'FontUnits','normalized', 'FontWeight','Bold',...
    'BackgroundColor',[0.7 0.7 0.7],'ForegroundColor','k',...
    'Position',[650/2-(300/2), 390, 300,35]);
hwaterleveltitle = uicontrol('Style','Text',...
    'String','Water Level: Good',...
    'FontUnits','normalized', 'FontWeight','Bold',...
    'BackgroundColor',[180/255,180/255,180/255],'ForegroundColor','k',...
    'Position',[465 510 150 25]);
%% Creating Buttons
hcollect = uicontrol('Style','togglebutton',...
    'String', 'Collect Temperatures','FontUnits','normalized',...
    'Position',[465 230 150 25],...
    'Callback',{@collect_Callback});
hsave = uicontrol('Style','pushbutton',...
    'String','Stop and Save', 'FontUnits','normalized',...
    'Position',[465 200 150 25],...
    'Callback',{@save_Callback});
hexit = uicontrol('Style','pushbutton',...
    'String','Exit','FontUnits','normalized',...
    'Position',[465 170 150 25],...
    'Callback',{@exit_Callback});
hpump1 = uicontrol('Style','togglebutton',...
    'String', 'Off','FontUnits','normalized',...
    'Position',[480 230 35 35],...
    'Callback',{@pump1_Callback});
hpump2 = uicontrol('Style','togglebutton',...
    'String', 'Off','FontUnits','normalized',...
    'Position',[490 230 35 35],...
    'Callback',{@pump2_Callback});
hled1 = uicontrol('Style','togglebutton','Enable','inactive',...
    'Position',[465, 110, 50, 25],...
    'BackgroundColor',[100/255,110/255,100/255]);
hled2 = uicontrol('Style','togglebutton','Enable','inactive',...
    'Position',[465, 110, 50, 25],...
    'BackgroundColor',[100/255,110/255,100/255]);
htpump1=uicontrol('Style','text',...
    'Position',[465 150 60 15],...
    'String','Hot Pump',...
    'FontUnits','normalized','FontWeight','Bold',...
    'BackgroundColor',[180/255,180/255,180/255],...
    'ForegroundColor',[1 0 0]);
htpump2=uicontrol('Style','text',...
    'Position',[465 150 60 15],...
    'String','Cold Pump',...
    'FontUnits','normalized','FontWeight','Bold',...
    'BackgroundColor',[180/255,180/255,180/255],...
    'ForegroundColor',[0 0 1]);
htankled1 = uicontrol('Style', 'togglebutton','Enable','Inactive',...
    'Position',[465,400,50,25],...
    'BackgroundColor',[110/255,100/255,100/255]);
htankled2 = uicontrol('Style', 'togglebutton','Enable','Inactive',...
    'Position',[465,400,50,25],...
    'BackgroundColor',[110/255,100/255,100/255]);
htanktitle1= uicontrol('Style','text',...
    'Position',[465 450 60 15],...
    'String','Tank 1',...
    'FontUnits','normalized','FontWeight','Bold',...
    'BackgroundColor',[180/255,180/255,180/255],...
    'ForegroundColor',[0 0 1]);
htanktitle2= uicontrol('Style','text',...
    'Position',[465 450 60 15],...
    'String','Tank 2',...
    'FontUnits','normalized','FontWeight','Bold',...
    'BackgroundColor',[180/255,180/255,180/255],...
    'ForegroundColor',[0 0 1]);
%% Temperature Display

htemp1=uicontrol('Style','text','BackgroundColor','w',...
     'Position',[515 375 50 20],...
     'String','--','FontUnits','normalized');
htext1=uicontrol('Style','text',...
    'Position',[465 375 50 14],...
    'String','T_H-In','FontUnits','normalized');
htemp2=uicontrol('Style','text','BackgroundColor','w',...
     'Position',[515 355 50 20],...
     'String','--','FontUnits','normalized');
htext2=uicontrol('Style','text',...
    'Position',[465 355 50 14],...
    'String','T_C-In','FontUnits','normalized');
htemp3=uicontrol('Style','text','BackgroundColor','w',...
     'Position',[515 335 50 20],...
     'String','--','FontUnits','normalized');
htext3=uicontrol('Style','text',...
    'Position',[465 335 50 14],...
    'String','T_C-Out','FontUnits','normalized');
htemp4=uicontrol('Style','text','BackgroundColor','w',...
     'Position',[515 315 50 20],...
     'String','--','FontUnits','normalized');
htext4=uicontrol('Style','text',...
    'Position',[465 315 50 14],...
    'String','T_H-Out','FontUnits','normalized');

%% Creating Plot
ha=axes('Units','pixels','Position',[50, 60, 350, 365]);
xlabel('Time (mins)')
ylabel('Temperature (C)')
ylim([0 80])
xlim('auto')
grid on

%% Aligning all the Text, Displays, and Buttons 
align([hcollect,hsave,hexit],'Center','Fixed',5)
align([hcollect,htemp4],'Center','Fixed',10)
align([hcollect,htext4],'Left','Fixed',10)
align([htemp4,htext4,],'Distributed','Middle')
align([htemp1,htemp2,htemp3,htemp4],'Center','Fixed',0)
align([htext1,htext2,htext3,htext4],'Center','Fixed',0)
align([htemp1,htext1,],'Distributed','Middle')
align([htemp2,htext2,],'Distributed','Middle')
align([htemp3,htext3,],'Distributed','Middle')
align([ha,hpump1,hpump2],'None','Bottom')
align([hcollect,htankled1,htanktitle1],'Left','None')
align([hcollect,htankled2,htanktitle2],'Right','None')
align([htankled1,htemp1],'None','Fixed',5)
align([htankled2,htemp1],'None','Fixed',5)
align([hwaterleveltitle,hcollect],'Center','None')
align([htankled1,htanktitle1],'Center','Fixed',0)
align([htankled2,htanktitle2],'Center','Fixed',0)
align([htanktitle1,hwaterleveltitle],'None','Fixed',5)
align([hexit,hpump1,hled1,htpump1],'Left','None')
align([hexit,hpump2,hled2,htpump2],'Right','None')
align([hpump1,hled1,htpump1],'Center','Fixed',5)
align([hpump2,hled2,htpump2],'Center','Fixed',5)
align([ha,htitle],'None','Fixed',10)
align([f,htitle],'Center','None')
% Adjusts all sizes and fonts when window is adjusted
f.Units='normalized';
ha.Units='normalized';
hcollect.Units='normalized';
hsave.Units='normalized';
hexit.Units='normalized';
htpump1.Units='normalized';
htpump2.Units='normalized';
htanktitle1.Units='normalized';
htanktitle2.Units='normalized';
hled1.Units='normalized';
hled2.Units='normalized';
htankled1.Units='normalized';
htankled2.Units='normalized';
hpump1.Units='normalized';
hpump2.Units='normalized';
htemp1.Units='normalized';
htext1.Units='normalized';
htemp2.Units='normalized';
htext2.Units='normalized';
htemp3.Units='normalized';
htext3.Units='normalized';
htemp4.Units='normalized';
htext4.Units='normalized';
htitle.Units='normalized';
hwaterleveltitle.Units='normalized';
% Show Window
movegui(f,'center')
f.Visible='on';
readtemps;
%% Simple Functions for the main code
    function pumppower(x,y,z)
        writeDigitalPin(x,pump{y},z);
        if (y == 2) && (z == 1)
            hpump2.String='On';
            hled2.BackgroundColor=[100/255,225/255,100/255];
        elseif (y == 2) && (z == 0)
            hpump2.String='Off';
            hled2.BackgroundColor=[100/255,110/255,100/255];
        elseif (y == 1) && (z == 1)
            hpump1.String='On';
            hled1.BackgroundColor=[100/255,225/255,100/255];
        elseif (y == 1) && (z == 0)
            hpump1.String='Off';
            hled1.BackgroundColor=[100/255,110/255,100/255];
        end
    end
    function readtemps
        Temp = zeros(4,3);
        while get(hcollect,'Value') == 0
            if Exit == true
                    fclose('all');
                    clear all
                    close all
                    break
            end
            checkwaterlevel;
            for j = 1:size(Temp,2)
            for i=1:L
                    reset(sensors);
                    write(sensors,sensors.AvailableAddresses{i},hex2dec('44'),true);
                    pause(0.07);
                    reset(sensors);
                    write(sensors,sensors.AvailableAddresses{i},hex2dec('BE'));
                    D(i,:)=read(sensors,sensors.AvailableAddresses{i},9);
            end
                raw = bitshift(D(:,2),8)+D(:,1);
                raw = typecast(uint16(raw), 'int16');
                Temp(:,j)=A.*double(raw).^2+B.*double(raw)+C+OFFSET;
            end
            temp = mean(Temp,2);
            %Displaying Temperatures
                set(htemp1,'String',[num2str(temp(1),'%.2f') '°C']);
                set(htemp2,'String',[num2str(temp(2),'%.2f') '°C']);
                set(htemp3,'String',[num2str(temp(3),'%.2f') '°C']);
                set(htemp4,'String',[num2str(temp(4),'%.2f') '°C']);
                
        end
    end
    function checkwaterlevel
        tank1=readDigitalPin(a,'D9');
        tank2=readDigitalPin(a,'D8');
        if tank1 == 0
            htankled1.BackgroundColor = [255/255,50/255,50/255];
        else
            htankled1.BackgroundColor = [110/255,100/255,100/255];
        end
        if tank2 == 0
            htankled2.BackgroundColor = [255/255,50/255,50/255];
        else
            htankled2.BackgroundColor = [110/255,100/255,100/255];
        end
        if tank2 == 0 && tank1 == 0
            hwaterleveltitle.String = 'Water Level: LOW!';
            hwaterleveltitle.ForegroundColor = [1,0,0];
        elseif tank2 == 0 || tank1 == 0
            hwaterleveltitle.String = 'Water Level: BATCH';
            hwaterleveltitle.ForegroundColor = [255/255,128/255,0];
        else
            hwaterleveltitle.String = 'Water Level: GOOD';
            hwaterleveltitle.ForegroundColor = [0,0,0];
        end
    end
%% Programming all the buttons
    function collect_Callback(source,eventdata)
        if get(hcollect,'Value')==1
            clc
            cla
            disp('Recording...');
            Exit = false;
            Window=101;
            x=0;
            
            %File dialog: Save function
            [filename,filepath]=uiputfile({'*.txt';'*.mat'},'Save as',userpath);
            userpath(filepath);
            fullpath=strcat(filepath,filename);
            fid=fopen(fullpath,'a');
            fprintf(fid,'%s\t %s\r\n','Time (mins)','Temp');
            
            %Data Collection from the four modules
            set(hpump1,'Value',true);
            pumppower(a,1,1);
            set(hpump2,'Value',true);
            pumppower(a,2,1);
            starttime=clock;
            Temp=zeros(4,3);
            while get(hcollect,'Value') == 1
                endtime=clock;
                
                if x<Window
                    x=x+1;
                end
                elptime=etime(endtime,starttime)/60;
                %% Calculating Average Temperature
                for j = 1:size(Temp,2)
                    %Start Reading
                for i=1:L
                    reset(sensors);
                    write(sensors,sensors.AvailableAddresses{i},hex2dec('44'),true);
                    pause(0.1);
                    reset(sensors);
                    write(sensors,sensors.AvailableAddresses{i},hex2dec('BE'));
                    D(i,:)=read(sensors,sensors.AvailableAddresses{i},9);
                end
                %End reading
                
                %Convert
                raw = bitshift(D(:,2),8)+D(:,1);
                raw = typecast(uint16(raw), 'int16');
                Temp(:,j)=A.*double(raw).^2+B.*double(raw)+C+OFFSET;
                end
                %Averaging
                temp = mean(Temp,2);
                moving(x,1:5)=[elptime,temp'];
                h=size(moving,1);
                if h>=Window
                    for k=1:Window-1
                        moving(k,:)=moving(k+1,:);
                    end
                    moving(h,:)=[];
                end
            %Plotting and displaying the Data Collected
                set(htemp1,'String',[num2str(temp(1),'%.2f') '°C']);%Hot IN
                set(htemp2,'String',[num2str(temp(2),'%.2f') '°C']);%Cold IN
                set(htemp3,'String',[num2str(temp(3),'%.2f') '°C']);%Cold OUT
                set(htemp4,'String',[num2str(temp(4),'%.2f') '°C']);%Hot OUT
                
                P = plot(moving(:,1),moving(:,2),'r*-',...
                    moving(:,1),moving(:,3),'b*-',...
                    moving(:,1),moving(:,4),'c*-',...
                    moving(:,1),moving(:,5),'m*-');
                
                %Legend (If changing thermocouples, update here)
                legend(P,'T_{H-In}','T_{C-In}','T_{C-Out}','T_{H-Out}')
                axis tight
                xlabel(['Time: ' num2str(elptime,'%.2f') ' mins'])
                ylabel('Temperature (C)')
                ylim([0 80])
                xlim('auto')
                grid on
                
                fprintf(fid,'%.2f\t %.2f\t %.2f\t %.2f\t %.2f\r\n',...
                    elptime,temp(1),temp(2),temp(3),temp(4));
                
            end
            fclose(fid);
            disp('Saved!')
            set(hpump1,'Value',false);
            pumppower(a,1,0);
            set(hpump2,'Value',true);
            pumppower(a,2,0);
            
        else
            readtemps;
        end
    end

    function save_Callback(source,eventdata)
        set(hcollect, 'Value',0);
        clc
    end

    function exit_Callback(source,eventdata)
        if get(hcollect, 'Value') == true
            choice=questdlg('You are still recording! Do you still want to exit?','WARNING!','Yes','No','No');
            switch choice
                case 'Yes'
                    set(hcollect,'Value',0);
                    Exit = true;
                case 'No'
                    return;
            end
        else
            clc
            cla
            Exit=true;
        end
    end

    function pump1_Callback(source,eventdata)
        if get(hpump1,'Value') == true
            pumppower(a,1,1);
        else
            pumppower(a,1,0);
        end
    end

    function pump2_Callback(source,eventdata)
        if get(hpump2,'Value') == true
            pumppower(a,2,1);
        else
            pumppower(a,2,0);
        end
    end
end