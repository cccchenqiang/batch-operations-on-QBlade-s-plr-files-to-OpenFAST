% plr2polar.m
% 批量导入极坐标文件并使用 WritePolarAD15 处理的脚本
%
% 功能说明：
% - 允许用户通过图形界面选择包含极坐标文件的文件夹
% - 处理指定文件夹中的 .plr 文件
% - 数据从第 18 行开始，包含攻角 (AOA)、升力系数 (CL)、阻力系数 (CD)、扭矩系数 (CM) 等列
% - 仅提取前四列 (AOA, CL, CD, CM)
% - 从第 14 行第 2 列提取雷诺数（Re），若未找到则默认为 100 万
% - 使用 textscan 处理连续空格或制表符，确保正确解析数据
% - 输出文件保存到用户选择的输入文件夹中的 'output_polars' 子文件夹
% - 检查输入数据的有效性（非 NaN/Inf，攻角范围）
%
% 使用说明：
% - 确保 WritePolarAD15.m 文件在 MATLAB 路径中或与本脚本在同一目录
% - .plr 文件的格式按照QBlade2.0.8.5版本输出的plr文件一致（数据从第 18 行开始，空格或制表符分隔）
% - 输出文件以 '_AD15.txt' 后缀命名，保存在输出output_polars文件夹中

% 让用户选择包含 .plr 文件的输入文件夹
input_dir = uigetdir(pwd, '选择包含 .plr 文件的文件夹');
if input_dir == 0
    error('用户取消了文件夹选择');
end

% 定义输出文件夹（在输入文件夹内创建 'output_polars' 子文件夹）
output_dir = fullfile(input_dir, 'output_polars');
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

% 获取输入文件夹中所有 .plr 文件的列表
file_list = dir(fullfile(input_dir, '*.plr'));

% 检查是否找到 .plr 文件
if isempty(file_list)
    error('在 %s 中未找到 .plr 文件', input_dir);
end

% 初始化日志文件以记录处理结果
log_file = fullfile(output_dir, 'processing_log.txt');
fid_log = fopen(log_file, 'w', 'n', 'UTF-8');
fprintf(fid_log, '极坐标文件处理日志 - %s\n', datestr(now));

% 循环处理每个 .plr 文件
for i = 1:length(file_list)
    % 获取输入文件的完整路径
    input_file = fullfile(input_dir, file_list(i).name);
    
    % 尝试检测分隔符（空格或制表符）
    try
        fid = fopen(input_file, 'r', 'n', 'UTF-8');
        sample_line = fgetl(fid);
        for j = 2:18 % 读取到第 18 行，检查数据部分的第 1 行
            sample_line = fgetl(fid);
        end
        fclose(fid);
        if contains(sample_line, '\t')
            delimiter = '\t'; % 使用制表符
            fprintf('文件 %s 使用制表符分隔\n', file_list(i).name);
            fprintf(fid_log, '文件 %s 使用制表符分隔\n', file_list(i).name);
        else
            delimiter = ' '; % 默认使用空格
            fprintf('文件 %s 使用空格分隔\n', file_list(i).name);
            fprintf(fid_log, '文件 %s 使用空格分隔\n', file_list(i).name);
        end
    catch e
        delimiter = ' '; % 默认空格
        fprintf('文件 %s 分隔符检测失败: %s，默认为空格\n', file_list(i).name, e.message);
        fprintf(fid_log, '文件 %s 分隔符检测失败: %s，默认为空格\n', file_list(i).name, e.message);
    end
    
    % 使用 textscan 读取 .plr 文件，跳过前 17 行，处理连续空格或制表符
    try
        fid = fopen(input_file, 'r', 'n', 'UTF-8');
        % 跳过前 17 行
        for j = 1:17
            fgetl(fid);
        end
        % 读取数据，假设 7 列（AOA, CL, CD, CM, CL_ATT, CL_SEP, F_ST）
        data_cell = textscan(fid, '%f %f %f %f %f %f %f', ...
            'Delimiter', delimiter, 'MultipleDelimsAsOne', true, 'CollectOutput', true);
        fclose(fid);
        data = data_cell{1}; % 转换为矩阵
    catch e
        fprintf('读取文件 %s 时出错: %s\n', file_list(i).name, e.message);
        fprintf(fid_log, '读取文件 %s 失败: %s\n', file_list(i).name, e.message);
        continue;
    end
    
    % 验证数据是否包含至少 4 列
    if size(data, 2) < 4
        fprintf('文件 %s 数据列数不足（实际 %d 列，需至少 4 列）\n', file_list(i).name, size(data, 2));
        fprintf(fid_log, '文件 %s 数据列数不足（实际 %d 列，需至少 4 列）\n', file_list(i).name, size(data, 2));
        continue;
    end
    
    % 提取前四列（AOA, CL, CD, CM）
    PolarIn = data(:, 1:4);
    
    % 检查数据是否包含非有限值（NaN 或 Inf）
    if any(~isfinite(PolarIn(:)))
        fprintf('文件 %s 包含非有限值（NaN 或 Inf），跳过处理\n', file_list(i).name);
        fprintf(fid_log, '文件 %s 包含非有限值（NaN 或 Inf），跳过处理\n', file_list(i).name);
        continue;
    end
    
    % 检查攻角范围是否覆盖 -180° 到 180°
    aoa = PolarIn(:, 1);
    if min(aoa) > -180 || max(aoa) < 180
        fprintf('警告: 文件 %s 的攻角范围 [%.1f, %.1f] 未覆盖 -180° 到 180°\n', ...
            file_list(i).name, min(aoa), max(aoa));
        fprintf(fid_log, '警告: 文件 %s 的攻角范围 [%.1f, %.1f] 未覆盖 -180° 到 180°\n', ...
            file_list(i).name, min(aoa), max(aoa));
    end
    
    % 从文件中提取雷诺数（从第 14 行第 2 列）
    try
        fid = fopen(input_file, 'r', 'n', 'UTF-8');
        lines = textscan(fid, '%s', 'Delimiter', '\n');
        fclose(fid);
        re_line = lines{1}{14}; % 第 14 行包含雷诺数

        re_values = split(strtrim(re_line)); % 按空格分割行
        if length(re_values) >= 2
            Re = str2double(re_values{2}) / 1e6; % 提取第 2 列，转换为百万单位
            if isnan(Re)
                Re = 1; % 若提取失败，默认为 100 万
            end
        else
            Re = 1; % 若行格式不符合预期，默认为 100 万
        end



%         re_values = split(strtrim(re_line), delimiter); % 使用检测到的分隔符
%         if length(re_values) >= 2
%             Re = str2double(re_values{2}) / 1e6; % 提取第 2 列，转换为百万单位
%             if isnan(Re)
%                 Re = 1; % 若提取失败，默认为 100 万
%                 fprintf('文件 %s 的雷诺数提取失败，默认为 100 万\n', file_list(i).name);
%                 fprintf(fid_log, '文件 %s 的雷诺数提取失败，默认为 100 万\n', file_list(i).name);
%             end
%         else
%             Re = 1; % 若行格式不符合预期，默认为 100 万
%             fprintf('文件 %s 的第 14 行格式错误，雷诺数默认为 100 万\n', file_list(i).name);
%             fprintf(fid_log, '文件 %s 的第 14 行格式错误，雷诺数默认为 100 万\n', file_list(i).name);
%         end
%     catch e
%         Re = 1; % 若读取失败，默认为 100 万
%         fprintf('文件 %s 的雷诺数读取失败: %s，默认为 100 万\n', file_list(i).name, e.message);
%         fprintf(fid_log, '文件 %s 的雷诺数读取失败: %s，默认为 100 万\n', file_list(i).name, e.message);
%     end
    
    % 从文件名提取雷诺数（作为交叉验证）
%     re_match = regexp(file_list(i).name, 'Re(\d+\.\d+)', 'tokens');
%         if ~isempty(re_match)
%             Re_from_name = str2double(re_match{1}{1}) / 1000; % 转换为百万单位
%             if abs(Re - Re_from_name) > 1e-3
%                 fprintf('警告: 文件 %s 的雷诺数（文件内容: %.3f 百万，文件名: %.3f 百万）不一致\n', ...
%                     file_list(i).name, Re, Re_from_name);
%                 fprintf(fid_log, '警告: 文件 %s 的雷诺数（文件内容: %.3f 百万，文件名: %.3f 百万）不一致\n', ...
%                     file_list(i).name, Re, Re_from_name);
%             end
   end
    
    % 生成输出文件名（例如，将 .plr 替换为 _AD15.txt）
    [~, name, ~] = fileparts(file_list(i).name);
    output_file = fullfile(output_dir, [name, '_AD15.txt']);
    
    % 从文件中提取标签（POLARNAME，假定在第 10 行）
    try
        label_line = lines{1}{10};
        label = strtrim(regexp(label_line, '(?<=POLARNAME\s*-\s*).*', 'match', 'once'));
        if isempty(label)
            label = name; % 若未找到标签，则使用文件名
            fprintf('文件 %s 的 POLARNAME 未找到，使用文件名作为标签\n', file_list(i).name);
            fprintf(fid_log, '文件 %s 的 POLARNAME 未找到，使用文件名作为标签\n', file_list(i).name);
        end
    catch
        label = name; % 若读取失败，使用文件名
        fprintf('文件 %s 的 POLARNAME 读取失败，使用文件名作为标签\n', file_list(i).name);
        fprintf(fid_log, '文件 %s 的 POLARNAME 读取失败，使用文件名作为标签\n', file_list(i).name);
    end
    
    % 调用 WritePolarAD15 处理并写入极坐标数据
    try
        [alpha0, alpha1, alpha2, C_nalpha, Cn1, Cn2, Cd0, Cm0] = ...
            WritePolarAD15(PolarIn, output_file, label, Re);
        fprintf('成功处理文件 %s\n', file_list(i).name);
        fprintf(fid_log, '成功处理文件 %s\n', file_list(i).name);
    catch e
        fprintf('处理文件 %s 时出错: %s\n', file_list(i).name, e.message);
        fprintf(fid_log, '处理文件 %s 失败: %s\n', file_list(i).name, e.message);
    end
end

% 关闭日志文件
fclose(fid_log);
fprintf('批量处理完成。处理日志已保存至 %s\n', log_file);


% 脚本用于将多个极化文件合并为一个文件
% 保留第一个文件的首10行，并将后续文件的表格数据纵向追加
% 
% clear all;
% close all;

% 包含极化文件的目录
inputDir = 'output_polars';
outputFile = fullfile(inputDir, 'merged_polar.txt');

% 获取目录中所有.txt文件的列表，除去后处理的日志文件
fileList = dir(fullfile(inputDir, '*.txt'));
fileList = fileList(~strcmp({fileList.name}, 'processing_log.txt'));
% 检查是否有文件
if isempty(fileList)
    error('目录中未找到.txt文件：%s', inputDir);
end

% 初始化变量
allTables = {};
numTabs = 0;

% 处理每个文件
for i = 1:length(fileList)
    filePath = fullfile(inputDir, fileList(i).name);
    fprintf('正在处理文件：%s\n', fileList(i).name);
    
    % 读取文件
    fid = fopen(filePath, 'r');
    if fid == -1
        warning('无法打开文件：%s', filePath);
        continue;
    end
    
    % 读取所有行
    lines = {};
    while ~feof(fid)
        lines{end+1} = fgetl(fid);
    end
    fclose(fid);
    
    % 对于第一个文件，存储头部（第1-10行）
    if i == 1
        header = lines(1:10);
        % 找到NumTabs行（通常是第6行），以便后续更新
        numTabsLineIdx = find(cellfun(@(x) contains(x, 'NumTabs'), header));
    end
    
    % 找到表格数据的起始行（第11行开始）
    tableStartIdx = 11;
    if length(lines) < tableStartIdx
        warning('文件 %s 的行数少于11行，跳过。', fileList(i).name);
        continue;
    end
    
    % 存储表格数据（从第11行到末尾）
    allTables{end+1} = lines(tableStartIdx:end);
    numTabs = numTabs + 1;
end

% 更新头部中的NumTabs值
%header{numTabsLineIdx} = sprintf('%d             NumTabs       - ! 本文件中空气动力学表格的数量。每个表格必须包含Re和Ctrl行。', numTabs);
header{numTabsLineIdx} = sprintf('%d             NumTabs       - ! Number of airfoil tables in this file. Each table must have lines for Re and Ctrl', numTabs);
% 写入合并后的文件
fid = fopen(outputFile, 'w');
if fid == -1
    error('无法打开输出文件：%s', outputFile);
end

% 写入头部
for i = 1:length(header)
    fprintf(fid, '%s\n', header{i});
end

% 写入所有表格
for i = 1:length(allTables)
    tableLines = allTables{i};
    for j = 1:length(tableLines)
        fprintf(fid, '%s\n', tableLines{j});
    end
end

fclose(fid);
fprintf('合并后的极化文件已写入：%s\n', outputFile);

