classdef Covid_Case_Statistic < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                   matlab.ui.Figure
        OptionButtonGroup          matlab.ui.container.ButtonGroup
        DailyButton                matlab.ui.control.RadioButton
        CumulativeButton           matlab.ui.control.RadioButton
        DatatoPlotButtonGroup      matlab.ui.container.ButtonGroup
        BothButton                 matlab.ui.control.RadioButton
        DeathsButton               matlab.ui.control.RadioButton
        CasesButton                matlab.ui.control.RadioButton
        AveragedofdaysSlider       matlab.ui.control.Slider
        AveragedofdaysSliderLabel  matlab.ui.control.Label
        StateorRegionListBox       matlab.ui.control.ListBox
        StateorRegionListBoxLabel  matlab.ui.control.Label
        CountryListBox             matlab.ui.control.ListBox
        CountryListBoxLabel        matlab.ui.control.Label
        UIAxes                     matlab.ui.control.UIAxes
    end

    
    properties (Access = private)   
        date                   % 所有Date(Datetime型態)
        dateTickIdx            % 要顯示在X軸的Date的Index  
        GlobalObject           % 儲存Global, Country, Region的所有資料的物件
                               % 有name, tier, data三種properties
        countryName            % 所有Country的名字(除了Global, Cell型態)
        selCountry             % 使用者選擇的國家名稱(Char型態)
        avgWindow              % 移動平均的取樣數  
        caseCum                % 使用者選擇的國家的所有Case(Double型態, Cumulate形式)             
        deathCum               % 使用者選擇的國家的所有Death(Double型態, Cumulate形式) 
        caseDaily              % 使用者選擇的國家的所有Case(Double型態, Daily形式)
        deathDaily             % 使用者選擇的國家的所有Death(Double型態, Daily形式)                   
        caseAvg                % 使用者選擇的國家的Case的平均值
        deathAvg               % 使用者選擇的國家的Death的平均值           
        selRegion              % 使用者選擇的地區名稱(Char型態)
    end
    
    methods (Access = private)
        % 建立含所有Country, Region資料的物件
        function Create_obj(app)
            % 讀取檔案
            load('Covid DATA.mat', 'covid_data');
            
            % 提取Date數據(X軸)
            app.date = datetime(covid_data(1, 3:end));
            app.dateTickIdx = 1:round((size(app.date, 2)/8)):size(app.date, 2);
            
            % 計算全球統計數據
            allDataCell = covid_data(2:end, 3:end);
            globalCases = sum(cellfun(@(x) x(1), allDataCell));
            globalDeaths = sum(cellfun(@(x) x(2), allDataCell));
            
            % 組合成Cell型態、存到物件中
            globalCell = cell(1, length(globalCases));
            for i = 1:length(globalCases)
                globalCell{i} = [globalCases(i), globalDeaths(i)];
            end
            globalObj = Global_data('Global', globalCell);

            % 把所有國家、地區的資料按階級存到物件中
            row = 2;
            while row <= size(covid_data, 1)
                country = covid_data{row, 1};
                region = covid_data{row, 2};
                selCell = covid_data(row, 3:end);

                if isempty(region)
                    countryObj = Global_data(country, selCell);
                    row = row + 1;

                    while row <= size(covid_data, 1) && ~isempty(covid_data{row, 2})
                        region = covid_data{row, 2};
                        selCell = covid_data(row, 3:end);
                        regionObj = Global_data(region, selCell);
                        countryObj = countryObj.Add_tier(regionObj);
                        row = row + 1;
                    end

                    globalObj = globalObj.Add_tier(countryObj);
                else
                    row = row + 1;
                end
            end

            app.GlobalObject = globalObj;

            totalNumOfCountry = app.GlobalObject.tier;
            fprintf("# of country in global object: %s\n\n", num2str(length(totalNumOfCountry)));
        end
        
        % 在list box中顯示國家名稱
        function Show_country(app)
           app.CountryListBox.Items = [{'Global'}, app.countryName];
        end

        % 計算每日數據
        function Compute_daily(app)
            app.caseDaily = diff([0, app.caseCum]);
            app.caseDaily(app.caseDaily < 0) = 0;

            app.deathDaily = diff([0, app.deathCum]);
            app.deathDaily(app.deathDaily < 0) = 0;
        end

        % 計算平均數據
        function Compute_average(app)
            if app.CumulativeButton.Value
                app.caseAvg = movmean(app.caseCum, [app.avgWindow-1 0]);
                app.deathAvg = movmean(app.deathCum, [app.avgWindow-1 0]);
            else
                app.caseAvg = movmean(app.caseDaily, [app.avgWindow-1 0]);
                app.deathAvg = movmean(app.deathDaily, [app.avgWindow-1 0]);
            end
        end
        
        % 繪製標題
        function Plot_title(app)
            % 讀取當前圖表狀況
            option = app.OptionButtonGroup.SelectedObject.Text;
            data = app.DatatoPlotButtonGroup.SelectedObject.Text;
            country = app.CountryListBox.Value;
            region = app.StateorRegionListBox.Value;
            
            % 處理Data to Plot的Both按鈕
            if isequal(data, 'Both')
                data = 'Cases and Deaths';
            end
            
            % 處理Country的Global, Region的All選項
            if isequal(country, 'Global')
                country = ' Globally';
            elseif isequal(region, 'All')
                country = [' in ', country];
            else
                country = [' in ', region];
            end
            
            % 處理Averaged # = 1的情形
            if isequal(app.avgWindow, 1)
                average = '';
            else
                average = [' (', num2str(app.avgWindow), '-day mean)'];
            end
            
            % 組裝成標題
            app.UIAxes.Title.String = [option, ' Number of ', data, country, average];
        end

        % 繪製圖表
        function Plot_data(app)
            % 重製整張圖表
            reset(app.UIAxes);
            
            % 設定顏色
            red = [0.7 0.3 0.4];
            blue = [0.2 0.4 0.7];
            gray = [0.15 0.15 0.15];

            % 繪製數據
            if app.CasesButton.Value
                bar(app.UIAxes, app.date, app.caseAvg, 'FaceColor', blue);
            elseif app.DeathsButton.Value
                plot(app.UIAxes, app.date, app.deathAvg, 'Color', red);
            else
                yyaxis(app.UIAxes, 'left');
                bar(app.UIAxes, app.date, app.caseAvg, 'FaceColor', blue);
                hold(app.UIAxes, 'on');

                yyaxis(app.UIAxes, 'right');
                plot(app.UIAxes, app.date, app.deathAvg, 'Color',red);
                hold(app.UIAxes, 'off');
            end

            % Y座標軸設定
            if app.BothButton.Value
                yyaxis(app.UIAxes, 'left');
                app.UIAxes.YColor = blue;
                app.UIAxes.YAxis(1).Exponent = 0;
                ytickformat(app.UIAxes, '%,.0f');

                yyaxis(app.UIAxes, 'right');
                app.UIAxes.YColor = red;
                app.UIAxes.YAxis(2).Exponent = 0;
                ytickformat(app.UIAxes, '%,.0f');
            else
                app.UIAxes.YColor = gray;
                app.UIAxes.YAxis.Exponent = 0;
                ytickformat(app.UIAxes, '%,.0f');
            end

            % X座標軸設定
            app.UIAxes.XTick = app.date(app.dateTickIdx);
            xtickformat(app.UIAxes, 'MMM dd');
            app.UIAxes.XAxis.SecondaryLabel.Visible = 'off';
            
            % 格線、外框設定
            grid(app.UIAxes, "on");
            box(app.UIAxes, 'off');

            % 更新標題
            app.Plot_title();

            drawnow;
        end
        
        % 尋找某國家的對應資料
        function Search_country_data(app)
            % 判斷Global，找到該位置的所有資料
            if isequal(app.selCountry, 'Global')
                selCell = app.GlobalObject.data;
            else
                selCountryObj = app.Create_object(app.countryName, app.selCountry);
                selCell = selCountryObj.data;
            end
            
            % 分別提取Case, Death
            app.caseCum = cellfun(@(x) x(1), selCell);
            app.deathCum = cellfun(@(x) x(2), selCell);
        end

        % 尋找某地區的對應資料
        function Search_region_data(app)
            % 找到該地區的所有資料，從Country往下找
            selCountryIdx = find(strcmp(app.countryName, app.selCountry));
            selCountryObj = app.GlobalObject.tier(selCountryIdx);
            
            % 生成Region物件，後面的邏輯就和Search_country_data()相同
            allRegion = {selCountryObj.tier.name};
            selRegionIdx = find(strcmp(allRegion, app.selRegion));
            selRegionObj = selCountryObj.tier(selRegionIdx);
            selCell = selRegionObj.data;

            % 分別提取Case, Death
            app.caseCum = cellfun(@(x) x(1), selCell);
            app.deathCum = cellfun(@(x) x(2), selCell);
        end
        
        % 顯示某國家對應的State or Region
        function Show_region(app)
            % 判斷Global，找到該國家對應的地區
            if isequal(app.selCountry, 'Global')
                app.StateorRegionListBox.Items = "All";
            else
                selCountryObj = app.Create_object(app.countryName, app.selCountry);
                
                % 反映到List box上
                if isempty(selCountryObj.tier)
                    app.StateorRegionListBox.Items = "All";
                else
                    region = {selCountryObj.tier.name};
                    app.StateorRegionListBox.Items = [{'All'}, region];
                end
            end
        end
        
        % 用名稱建立對應的物件
        function obj = Create_object(app, nameList, targetName)
            selCountryIdx = find(strcmp(nameList, targetName));
            obj = app.GlobalObject.tier(selCountryIdx);
        end
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            % 建立物件
            app.Create_obj();

            % 初始化變數
            app.countryName = {app.GlobalObject.tier.name};
            app.selCountry = 'Global';
            app.avgWindow = app.AveragedofdaysSlider.Value;
            
            % 提取Case, Death數據(Y軸)
            app.Search_country_data();
            
            % 計算每日、平均數據
            app.Compute_daily();
            app.Compute_average();
            
            % 初始化圖表
            app.Show_country();
            app.StateorRegionListBox.Items = "All";
            app.Plot_data();
        end

        % Value changed function: CountryListBox
        function CountryListBoxValueChanged(app, event)
            % 改變值並顯示對應的地區
            app.selCountry = app.CountryListBox.Value;
            app.selRegion = 'All';
            app.Show_region();
            
            % 提取Case, Death數據
            app.Search_country_data();
            
            % 計算每日、平均並繪圖
            app.Compute_daily();
            app.Compute_average();
            app.Plot_data();
            fprintf("Country changed to : %s\n\n", app.selCountry);
        end

        % Value changed function: StateorRegionListBox
        function StateorRegionListBoxValueChanged(app, event)
            % 改變值
            app.selCountry = app.CountryListBox.Value;
            app.selRegion = app.StateorRegionListBox.Value;
            
            % 提取Case, Death數據
            if isequal(app.selRegion, 'All')
                app.Search_country_data();
            else
                app.Search_region_data();
            end
            
            % 計算每日、平均並繪圖
            app.Compute_daily();
            app.Compute_average();
            app.Plot_data;
            fprintf("Region changed to : %s\n\n", app.selRegion);
        end

        % Selection changed function: DatatoPlotButtonGroup
        function DatatoPlotButtonGroupSelectionChanged(app, event)
            % 重新繪圖
            app.Compute_daily();
            app.Compute_average();
            app.Plot_data();
        end

        % Selection changed function: OptionButtonGroup
        function OptionButtonGroupSelectionChanged(app, event)
            % 重新繪圖
            app.Compute_daily();
            app.Compute_average();
            app.Plot_data();
        end

        % Value changed function: AveragedofdaysSlider
        function AveragedofdaysSliderValueChanged(app, event)
            % 改變Average window的值
            app.avgWindow = round(app.AveragedofdaysSlider.Value);
            
            % 重新繪圖
            app.Compute_daily();
            app.Compute_average();
            app.Plot_data();
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 600 575];
            app.UIFigure.Name = 'MATLAB App';

            % Create UIAxes
            app.UIAxes = uiaxes(app.UIFigure);
            title(app.UIAxes, 'Cumulative Number of Cases Globally')
            app.UIAxes.GridAlpha = 0.05;
            app.UIAxes.XGrid = 'on';
            app.UIAxes.YGrid = 'on';
            app.UIAxes.Position = [38 207 526 342];

            % Create CountryListBoxLabel
            app.CountryListBoxLabel = uilabel(app.UIFigure);
            app.CountryListBoxLabel.HorizontalAlignment = 'right';
            app.CountryListBoxLabel.Position = [14 180 50 22];
            app.CountryListBoxLabel.Text = 'Country:';

            % Create CountryListBox
            app.CountryListBox = uilistbox(app.UIFigure);
            app.CountryListBox.Items = {'Global', 'Item 2', 'Item 3', 'Item 4'};
            app.CountryListBox.ValueChangedFcn = createCallbackFcn(app, @CountryListBoxValueChanged, true);
            app.CountryListBox.Position = [71 31 120 173];
            app.CountryListBox.Value = 'Global';

            % Create StateorRegionListBoxLabel
            app.StateorRegionListBoxLabel = uilabel(app.UIFigure);
            app.StateorRegionListBoxLabel.HorizontalAlignment = 'right';
            app.StateorRegionListBoxLabel.Position = [201 164 46 40];
            app.StateorRegionListBoxLabel.Text = {'State or'; 'Region:'};

            % Create StateorRegionListBox
            app.StateorRegionListBox = uilistbox(app.UIFigure);
            app.StateorRegionListBox.ValueChangedFcn = createCallbackFcn(app, @StateorRegionListBoxValueChanged, true);
            app.StateorRegionListBox.Position = [258 31 83 171];

            % Create AveragedofdaysSliderLabel
            app.AveragedofdaysSliderLabel = uilabel(app.UIFigure);
            app.AveragedofdaysSliderLabel.HorizontalAlignment = 'right';
            app.AveragedofdaysSliderLabel.Position = [355 167 56 30];
            app.AveragedofdaysSliderLabel.Text = {'Averaged'; '# of days'};

            % Create AveragedofdaysSlider
            app.AveragedofdaysSlider = uislider(app.UIFigure);
            app.AveragedofdaysSlider.Limits = [1 15];
            app.AveragedofdaysSlider.ValueChangedFcn = createCallbackFcn(app, @AveragedofdaysSliderValueChanged, true);
            app.AveragedofdaysSlider.Position = [424 191 150 3];
            app.AveragedofdaysSlider.Value = 1;

            % Create DatatoPlotButtonGroup
            app.DatatoPlotButtonGroup = uibuttongroup(app.UIFigure);
            app.DatatoPlotButtonGroup.SelectionChangedFcn = createCallbackFcn(app, @DatatoPlotButtonGroupSelectionChanged, true);
            app.DatatoPlotButtonGroup.Title = 'Data to Plot';
            app.DatatoPlotButtonGroup.Position = [355 31 100 105];

            % Create CasesButton
            app.CasesButton = uiradiobutton(app.DatatoPlotButtonGroup);
            app.CasesButton.Text = 'Cases';
            app.CasesButton.Position = [11 59 58 22];
            app.CasesButton.Value = true;

            % Create DeathsButton
            app.DeathsButton = uiradiobutton(app.DatatoPlotButtonGroup);
            app.DeathsButton.Text = 'Deaths';
            app.DeathsButton.Position = [11 37 60 22];

            % Create BothButton
            app.BothButton = uiradiobutton(app.DatatoPlotButtonGroup);
            app.BothButton.Text = 'Both';
            app.BothButton.Position = [11 15 65 22];

            % Create OptionButtonGroup
            app.OptionButtonGroup = uibuttongroup(app.UIFigure);
            app.OptionButtonGroup.SelectionChangedFcn = createCallbackFcn(app, @OptionButtonGroupSelectionChanged, true);
            app.OptionButtonGroup.Title = 'Option';
            app.OptionButtonGroup.Position = [474 31 100 105];

            % Create CumulativeButton
            app.CumulativeButton = uiradiobutton(app.OptionButtonGroup);
            app.CumulativeButton.Text = 'Cumulative';
            app.CumulativeButton.Position = [11 59 82 22];
            app.CumulativeButton.Value = true;

            % Create DailyButton
            app.DailyButton = uiradiobutton(app.OptionButtonGroup);
            app.DailyButton.Text = 'Daily';
            app.DailyButton.Position = [11 37 65 22];

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = Covid_Case_Statistic

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end