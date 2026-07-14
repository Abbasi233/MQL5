#include <Controls\Dialog.mqh>
#include <Controls\Button.mqh>
#include <Library/EventBus.mqh>

#define MS_PANEL_WIDTH   220
#define MS_PANEL_HEIGHT  280
#define MS_PANEL_MARGIN  10
#define MS_BUTTON_WIDTH  100
#define MS_BUTTON_HEIGHT 28

class MarketStructurePanel : public CAppDialog {
private:
    CButton m_button;
    EventBus* m_bus;

public:
    MarketStructurePanel(void);
    ~MarketStructurePanel(void);

    void SetEventBus(EventBus& bus);
    virtual bool Create(const long chart, const string name, const int subwin);
    virtual bool OnEvent(const int id, const long& lparam, const double& dparam, const string& sparam);

protected:
    bool CreateCenterButton(void);
    void OnClickButton(void);
};

EVENT_MAP_BEGIN(MarketStructurePanel)
ON_EVENT(ON_CLICK, m_button, OnClickButton)
EVENT_MAP_END(CAppDialog)

MarketStructurePanel::MarketStructurePanel(void) : m_bus(NULL) {
}

MarketStructurePanel::~MarketStructurePanel(void) {
}

void MarketStructurePanel::SetEventBus(EventBus& bus) {
    m_bus = &bus;
}

bool MarketStructurePanel::Create(const long chart, const string name, const int subwin) {
    int chartWidth = (int)ChartGetInteger(chart, CHART_WIDTH_IN_PIXELS);
    int x2 = chartWidth - MS_PANEL_MARGIN;
    int x1 = x2 - MS_PANEL_WIDTH;
    int y1 = MS_PANEL_MARGIN;
    int y2 = y1 + MS_PANEL_HEIGHT;

    if (x1 < MS_PANEL_MARGIN)
        x1 = MS_PANEL_MARGIN;

    if (!CAppDialog::Create(chart, name, subwin, x1, y1, x2, y2))
        return false;

    if (!CreateCenterButton())
        return false;

    return true;
}

bool MarketStructurePanel::CreateCenterButton(void) {
    int x1 = (ClientAreaWidth() - MS_BUTTON_WIDTH) / 2;
    int y1 = (ClientAreaHeight() - MS_BUTTON_HEIGHT) / 2;
    int x2 = x1 + MS_BUTTON_WIDTH;
    int y2 = y1 + MS_BUTTON_HEIGHT;

    if (!m_button.Create(m_chart_id, m_name + "Action", m_subwin, x1, y1, x2, y2))
        return false;
    if (!m_button.Text("Start"))
        return false;
    if (!Add(m_button))
        return false;

    return true;
}

void MarketStructurePanel::OnClickButton(void) {
    if (m_bus == NULL)
        return;

    Event event(EVENT_BOS, 0.0, TimeCurrent());
    m_bus.Publish(event);
}
