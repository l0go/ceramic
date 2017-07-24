import * as React from 'react';
import { observer } from 'utils';
import { Button, Form, Field, Panel, NumberInput, Title, Alt } from 'components';
import { project, VisualItem } from 'app/model';

@observer class VisualsPanel extends React.Component {

/// Lifecycle

    render() {

        let selectedVisual:VisualItem = null;
        if (project.ui.selectedItem != null && project.ui.selectedItem instanceof VisualItem) {
            selectedVisual = project.ui.selectedItem;
        }

        return (
            <Panel>
                {
                    selectedVisual != null
                    ?
                        <div>
                            <Title>Selected visual</Title>
                            <Alt>
                                <Form>
                                    <Field label="width">
                                        <NumberInput value={selectedVisual.width} onChange={(val) => { selectedVisual.width = val; }} />
                                    </Field>
                                    <Field label="height">
                                        <NumberInput value={selectedVisual.height} onChange={(val) => { selectedVisual.height = val; }} />
                                    </Field>
                                    <Field label="scaleX">
                                        <NumberInput value={selectedVisual.scaleX} onChange={(val) => { selectedVisual.scaleX = val; }} />
                                    </Field>
                                    <Field label="scaleY">
                                        <NumberInput value={selectedVisual.scaleY} onChange={(val) => { selectedVisual.scaleY = val; }} />
                                    </Field>
                                    <Field label="x">
                                        <NumberInput value={selectedVisual.x} onChange={(val) => { selectedVisual.x = val; }} />
                                    </Field>
                                    <Field label="y">
                                        <NumberInput value={selectedVisual.y} onChange={(val) => { selectedVisual.y = val; }} />
                                    </Field>
                                    <Field label="anchorX">
                                        <NumberInput value={selectedVisual.anchorX} onChange={(val) => { selectedVisual.anchorX = val; }} />
                                    </Field>
                                    <Field label="anchorY">
                                        <NumberInput value={selectedVisual.anchorY} onChange={(val) => { selectedVisual.anchorY = val; }} />
                                    </Field>
                                    <Field label="rotation">
                                        <NumberInput value={selectedVisual.rotation} onChange={(val) => { selectedVisual.rotation = val; }} />
                                    </Field>
                                    <Field label="skewX">
                                        <NumberInput value={selectedVisual.skewX} onChange={(val) => { selectedVisual.skewX = val; }} />
                                    </Field>
                                    <Field label="skewY">
                                        <NumberInput value={selectedVisual.skewY} onChange={(val) => { selectedVisual.skewY = val; }} />
                                    </Field>
                                </Form>
                            </Alt>
                        </div>
                    :
                        null
                }
                <Form>
                    <Field>
                        <Button
                            value="Add visual"
                            onClick={() => { project.ui.addingVisual = true; }}
                        />
                    </Field>
                </Form>
            </Panel>
        );

    } //render
    
}

export default VisualsPanel;
