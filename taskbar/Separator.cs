using System; using System.Drawing; using System.Windows.Forms;
static class P {
  [STAThread] static void Main(string[] a) {
    if (a.Length == 0 || a[0] != "--pin") return;   // a click on the pinned separator does nothing
    var f = new Form { Text = "Separator", Width = 460, Height = 150, StartPosition = FormStartPosition.CenterScreen,
      Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath), FormBorderStyle = FormBorderStyle.FixedDialog, MaximizeBox = false, MinimizeBox = false };
    f.Controls.Add(new Label { Dock = DockStyle.Fill, TextAlign = ContentAlignment.MiddleCenter, Font = new Font("Segoe UI", 11),
      Text = "Right-click this icon on the taskbar -> Pin to taskbar.\nThen just close this window." });
    Application.Run(f);
  }
}
