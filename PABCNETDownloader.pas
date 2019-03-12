program downloader;

const
  PABCFile = 'http://pascalabc.net/downloads/PascalABCNETSetup.exe';
  

var
  TempFolder := System.IO.Path.GetTempPath + 'PABCInstallerTemp';
  ExecHideFile := TempFolder + '\ExecHide.exe';
  PreCompileFile := 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\ngen.exe';
  AddToGACFile := TempFolder + '\gacutil.exe';
  TempFile := System.IO.Path.GetTempFileName;

var
  y := 0;
  wc := new System.Net.WebClient;
  file_pst: real;
  pst_done: real;
  pst_err: real;
  comp := false;
  
  procs_alive := new List<System.Diagnostics.Process>;

procedure AddOtp(s: string);
begin
  System.Console.SetCursorPosition(0, y);
  write(s, ' ' * (System.Console.WindowWidth-s.Length) );
  y += 1;
end;

procedure DeleteFolder(path: string);
begin
  if not System.IO.Directory.Exists(path) then exit;
  foreach var dir in System.IO.Directory.EnumerateDirectories(path) do DeleteFolder(dir);
  foreach var f in System.IO.Directory.EnumerateFiles(path) do System.IO.File.Delete(f);
  System.IO.Directory.Delete(path);
end;

type
  InstallableElement = abstract class
    
    from, &to: string;
    last_err:Exception;
    
    function GetFileCount:integer; abstract;
    
    function Install: List<InstallableElement>; abstract;
  
  end;
  
  InstallableFile = class(InstallableElement)
    
    function Install: List<InstallableElement>; override;
    begin
      try
        System.IO.File.Delete(&to);
        System.IO.File.Copy(from, &to);
        
        if System.IO.Path.GetExtension(&to) = '.exe' then procs_alive += System.Diagnostics.Process.Start($'{ExecHideFile}',$'{PreCompileFile} install {&to}');//.WaitForExit;
        if System.IO.Path.GetExtension(&to) = '.dll' then procs_alive += System.Diagnostics.Process.Start($'{ExecHideFile}',$'{AddToGACFile} /i {&to}');//.WaitForExit;
        
        Result := new List<InstallableElement>(0);
      except
        on e: Exception do
        begin
          self.last_err := e;
          Result := new List<InstallableElement>(1);
          Result.Add(self);
          pst_err += file_pst;
        end;
      end;
      pst_done += file_pst;
    end;
    
    function GetFileCount:integer; override :=
    1;
    
    constructor(from, &to: string);
    begin
      self.from := from;
      self.to := &to;
    end;
    
    public function ToString: string; override;
    begin
      var fi1 := new System.IO.FileInfo(from);
      var fi2 := new System.IO.FileInfo(&to);
      Result := $'Файл {fi1.FullName}=>{fi2.FullName}{#10*2}{last_err}{#10}';
    end;
  
  end;
  InstallableFolder = class(InstallableElement)
    
    Elements := new List<InstallableElement>;
    
    function Install: List<InstallableElement>; override;
    begin
      try
        Result := InstallBody;
      except
        on e: Exception do
        begin
          self.last_err := e;
          Result := new List<InstallableElement>(1);
          Result.Add(self);
          var pst := file_pst * self.GetFileCount;
          pst_done += pst;
          pst_err += pst;
        end;
      end;
    end;
    
    function InstallBody: List<InstallableElement>;
    begin
      Result := new List<InstallableElement>;
      
      System.IO.Directory.CreateDirectory(&to);
      
      foreach var el in Elements do
        Result.AddRange(el.Install);
      
    end;
    
    function GetFileCount:integer; override :=
    Elements.Select(el->el.GetFileCount).Sum;
    
    function GetElements: sequence of InstallableElement :=
    System.IO.Directory.EnumerateDirectories(from).Select(dir -> InstallableElement(
      new InstallableFolder(
        self.from + '\' + System.IO.Path.GetFileName(dir),
        self.&to + '\' + System.IO.Path.GetFileName(dir)
      )
    )) +
    System.IO.Directory.EnumerateFiles(from).Select(fl -> InstallableElement(
      new InstallableFile(
        self.from + '\' + System.IO.Path.GetFileName(fl),
        self.&to + '\' + System.IO.Path.GetFileName(fl)
      )
    ));
    
    constructor(from, &to: string);
    begin
      self.from := from;
      self.to := &to;
      Elements := GetElements.ToList;
    end;
    
    public function ToString: string; override;
    begin
      var fi1 := new System.IO.FileInfo(from);
      var fi2 := new System.IO.FileInfo(&to);
      Result := $'Папка {fi1.FullName}=>{fi2.FullName}{#10*2}{last_err}{#10}';
    end;
  
  end;

var
  FailedToInstall: List<InstallableElement>;

procedure Подготовка;
begin
  AddOtp('подготовка');
  System.IO.File.Delete(TempFile);
  wc.DownloadProgressChanged += procedure(o, e)-> pst_done := e.BytesReceived / e.TotalBytesToReceive;
  wc.DownloadFileCompleted += procedure(o, e)-> comp := true;
end;

procedure Скачивание;
begin
  AddOtp('скачиваю');
  wc.DownloadFileAsync(new System.Uri(PABCFile), TempFile);
  while not comp do
  begin
    AddOtp($'{pst_done*100:N2}%');
    y -= 1;
    Sleep(10);
  end;
end;

procedure DestroyWindow(ptr:System.IntPtr);
external 'User32.dll';

procedure Распаковка;
begin
  AddOtp('распаковываю');
  DeleteFolder(TempFolder);
  (**
  var p := new System.Diagnostics.Process;
  p.StartInfo.FileName := $'C:\Program Files\7-Zip\7zG.exe';
  //p.StartInfo.Arguments := $'x "{TempFile}" -o"{TempFolder}"';
  AddOtp($'{System.IO.Path.GetTempPath}\temp_donwload.exe');
  p.StartInfo.Arguments := $'x "{System.IO.Path.GetTempPath}\temp_donwload.exe" -o"{TempFolder}"';
  p.StartInfo.UseShellExecute := false;
  p.StartInfo.RedirectStandardError := true;
  p.StartInfo.CreateNoWindow := true;
  p.StartInfo.RedirectStandardOutput := true;
  p.Start;
  p.StandardError.ReadToEnd;
  p.StandardOutput.ReadToEnd;
  p.WaitForExit;
  (**)
  //System.Diagnostics.Process.Start($'C:\Program Files\7-Zip\7zG.exe',$'x "{TempFile*0+''temp_donwload.exe''}" -o"{TempFolder}" -bso0 -bsp0').WaitForExit;
  System.Diagnostics.Process.Start($'C:\Program Files\7-Zip\7zG.exe',$'x "{TempFile}" -o"{TempFolder}"').WaitForExit;
  System.IO.File.Delete(TempFile);
end;

procedure Установка(installing:List<InstallableElement>);
begin
  AddOtp($'Устанавливаю');
  FailedToInstall := new List<InstallableElement>;
  file_pst := 1/installing.Select(el->el.GetFileCount).Sum;
  pst_done := 0;
  pst_err := 0;
  comp := false;
  var thr := new System.Threading.Thread(()->
  begin
    foreach var el in installing do
      FailedToInstall.AddRange(el.Install);
    
    comp := true;
  end);
  thr.Start;
  while not comp do
  begin
    AddOtp($'{pst_done*100:N2}%');
    y -= 1;
    Sleep(10);
  end;
  
end;

procedure ОжиданиеЗакрытияПаскаля;
begin
  var pas_proc := System.Diagnostics.Process.GetProcessesByName('PascalABCNET');
  if pas_proc.Length <> 0 then
  begin
    AddOtp($'не удалось установить {pst_err:P}');
    AddOtp($'закройте паскаль, чтоб установить остальное');
    while pas_proc.Length <> 0 do
    begin
      pas_proc := pas_proc.Where(proc -> not proc.HasExited).ToArray;
      Sleep(100);
    end;
    Sleep(1000);
  end;
end;

begin
  
  try
    
    Подготовка;
    Скачивание;
    Распаковка;
    var try2 := System.Diagnostics.Process.GetProcessesByName('PascalABCNET').Length <> 0;
    Установка((
      
      System.IO.Directory.EnumerateDirectories(TempFolder)
      .Select(fname->System.IO.Path.GetFileName(fname))
      .Where(dir->not dir.StartsWith('$'))
      .Select(dir->InstallableElement(new InstallableFolder($'{TempFolder}\{dir}',$'C:\Program Files (x86)\PascalABC.NET\{dir}')))
      +
      System.IO.Directory.EnumerateFiles(TempFolder)
      .Select(fname->System.IO.Path.GetFileName(fname))
      //.Where(fname->fname<>'pabcworknet.ini')
      //.Where(fname->fname<>'gacutlrc.dll')
      //.Where(fname->fname<>'gacutil.exe.config')
      .Where(fname->System.IO.Path.GetExtension(fname) = '.exe')
      .Select(fname->InstallableElement(new InstallableFile($'{TempFolder}\{fname}',$'C:\Program Files (x86)\PascalABC.NET\{fname}')))
      +
      System.IO.Directory.EnumerateFiles(TempFolder)
      .Select(fname->System.IO.Path.GetFileName(fname))
      .Where(fname->fname<>'pabcworknet.ini')
//      .Where(fname->fname<>'gacutlrc.dll')
//      .Where(fname->fname<>'gacutil.exe.config')
      .Where(fname->System.IO.Path.GetExtension(fname) <> '.exe')
      .Select(fname->InstallableElement(new InstallableFile($'{TempFolder}\{fname}',$'C:\Program Files (x86)\PascalABC.NET\{fname}')))
      +
      (
        new InstallableFolder($'{TempFolder}\$_1_\Samples','C:\PABCWork.NET\Samples')
        as InstallableElement
      )
      
    ).ToList);
    if try2 and (FailedToInstall.Count <> 0) then
    begin
      ОжиданиеЗакрытияПаскаля;
      Установка(FailedToInstall);
    end;
    
    if FailedToInstall.Count <> 0 then
    begin
      AddOtp($'{FailedToInstall.Select(el->el.GetFileCount).Sum} файлов не было установлено:');
      FailedToInstall.PrintLines;
      readln;
    end;
    
    AddOtp('Жду окончания установочных процедур');
    while procs_alive.Any do
    begin
      procs_alive.RemoveAll(p->p.HasExited);
      Sleep(10);
    end;
    
    AddOtp('Удаляю папку в которую распоковывал');
    DeleteFolder(TempFolder);
    
  except
    on e: System.Exception do
    begin
      AddOtp('при выполнении возникла ошибка:');
      AddOtp(e.ToString);
      readln;
    end;
  end;
  
end.