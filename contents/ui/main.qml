import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // ----------------------------------------------------------------
    // CONFIGURATION — edit these two lines
    // ----------------------------------------------------------------
    // The command to run. The panel's shell is non-interactive, so
    // ~/.bashrc (and with it nvm) is never loaded — source nvm.sh
    // explicitly so `npx` is found regardless of the Node version.
    readonly property string command:
    "bash -c 'export NVM_DIR=\"$HOME/.nvm\"; . \"$NVM_DIR/nvm.sh\"; npx --yes ccusage@latest daily --json 2>/dev/null'"

    // How often to run it, in milliseconds.
    readonly property int intervalMs: 60 * 1000   // once a minute

    // ----------------------------------------------------------------
    // STATE
    // ----------------------------------------------------------------
    property string displayValue: "…"
    property bool hadError: false
    property string latestPeriod: ""

    // ----------------------------------------------------------------
    // RUN THE COMMAND
    // Connecting a source to the "executable" engine runs that string
    // as a command. We read the result in onNewData, then disconnect
    // so it behaves as a one-shot rather than a continuous stream.
    // ----------------------------------------------------------------
    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []

        onNewData: (sourceName, data) => {
            const stdout = (data["stdout"] || "").trim()
            const exitCode = data["exit code"]
            disconnectSource(sourceName)   // command finished

            if (exitCode !== 0 || stdout.length === 0) {
                root.hadError = true
                root.displayValue = "err"
                return
            }

            try {
                const parsed = JSON.parse(stdout)
                const days = parsed.daily || []
                if (days.length === 0) {
                    root.hadError = true
                    root.displayValue = "—"
                    return
                }

                // Find the most recent day. "period" is YYYY-MM-DD,
                // which sorts correctly as a plain string, so we don't
                // have to trust the array's ordering.
                let latest = days[0]
                for (let i = 1; i < days.length; i++) {
                    if (days[i].period > latest.period) {
                        latest = days[i]
                    }
                }

                root.latestPeriod = latest.period
                root.hadError = false
                root.displayValue = "$" + latest.totalCost.toFixed(2)
            } catch (e) {
                root.hadError = true
                root.displayValue = "err"
            }
        }

        function run(cmd) {
            connectSource(cmd)
        }
    }

    function refresh() {
        executable.run(root.command)
    }

    // ----------------------------------------------------------------
    // POLL ON A TIMER
    // ----------------------------------------------------------------
    Timer {
        interval: root.intervalMs
        running: true
        repeat: true
        triggeredOnStart: true   // also run immediately when loaded
        onTriggered: root.refresh()
    }

    // ----------------------------------------------------------------
    // WHAT SHOWS IN THE PANEL (compact representation)
    // ----------------------------------------------------------------
    preferredRepresentation: root.compactRepresentation

    compactRepresentation: PlasmaComponents.Label {
        id: panelLabel
        text: root.displayValue
        color: root.hadError ? Kirigami.Theme.negativeTextColor
                             : Kirigami.Theme.textColor
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        // Let the panel size the label to its text width
        Layout.preferredWidth: contentWidth + Kirigami.Units.smallSpacing * 2

        // Click the number to force an immediate refresh
        MouseArea {
            anchors.fill: parent
            onClicked: root.refresh()
        }
    }

    // ----------------------------------------------------------------
    // POPUP VIEW (full representation) — optional, shows on click when
    // the widget is on the desktop or if you set preferredRepresentation
    // to the full one.
    // ----------------------------------------------------------------
    fullRepresentation: PlasmaComponents.Label {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 8
        Layout.minimumHeight: Kirigami.Units.gridUnit * 4
        text: root.hadError ? "Last run failed"
                            : (root.latestPeriod + "\n" + root.displayValue)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
