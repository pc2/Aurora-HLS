# CI analysis

Quarto renders the collected pipeline results with its Julia engine.
The page structure and links are Markdown in `index.qmd`, Julia cells load measurements and display plots.
The benchmark plotting functions adapt `aurora_test/eval/plot.ipynb`, and the resource preparation and bars adapt `aurora_test/eval/plot_resource_consumption.jl` from the HEART paper evaluation.
The plots use the paper's CairoMakie layout, color scheme, latency calculation, and U280 normalization, with only this repository's pipeline results as inputs.
The paper's comparison datasets are not required.
Latency is elapsed time per iteration averaged across the tested instances, throughput is message bits divided by that mean latency.
Frame payloads use the HLS stream width, including the 64 byte HLS interface of the 400 MHz bridge.

The collection job reads successful bitstreams and passes their `SYSTEM_METADATA` to [report-parser-vitis](https://git.uni-paderborn.de/papeg/report-parser-vitis).
The pinned `parse-vitis-report` launcher uses the same uv installation pattern as the repository's topomux launcher.
The analysis selects routed utilization for `aurora_flow_0` and `aurora_flow_1` from the parsed report.
This supports cached builds without another synthesis run.
The bitstreams are excluded from the collection artifacts.
Resource plots report the mean per core and exclude the platform, HLS kernels, and external clock bridges.
Percentages use the full U280 capacity, BRAM is measured in 36 Kb blocks.

The final analysis stage renders every hardware enabled pipeline, and the default branch publishes the site to GitLab Pages.
Other branches expose the rendered site through the `analysis:render` job artifacts.
The generated site is stored in `analysis/_site`.
Each plot section includes only variants with measurements.
The sources CSV records availability and links to the original producer jobs.

Run the site locally after obtaining the `results:collect` artifacts.

```bash
bash ci/render-analysis.sh
```

Set `AURORA_RESULTS_FILE` to use another collected `hpc-ci-results.json` snapshot.
The render script loads `devel/quarto/1.8.26` and `lang/JuliaHPC/1.12.6-foss-2025a` and uses the shared Julia depot at `$HPC_CI_STORAGE_DIR/$HPC_CI_PACKAGE_NAME/$HPC_CI_PACKAGE_VERSION/julia-depot`.
Temporary files remain under `build-analysis`.
The pinned Julia environment is shared by Quarto and the plotting code.
The render script checks frame units and result selection before building the site.
