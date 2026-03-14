"""Data Visualization Optimizer: Statistical analysis and chart specification engine.

Analyzes numerical data, selects optimal chart types, scales, colors, and labels,
then produces a JSON-serializable ChartSpec. Numpy-only dependency.
"""
from __future__ import annotations

import json
import math
import sys
from dataclasses import dataclass, field, asdict
from enum import Enum
from typing import Any, Dict, List, Optional, Tuple


import numpy as np


# ---------------------------------------------------------------------------
# Enums
# ---------------------------------------------------------------------------

class ScaleType(str, Enum):
    LINEAR = "linear"
    LOG = "log"
    SYMLOG = "symlog"
    DIVERGING = "diverging"


class ChartType(str, Enum):
    HEATMAP = "heatmap"
    BAR = "bar"
    GROUPED_BAR = "grouped_bar"
    STACKED_BAR = "stacked_bar"
    LINE = "line"
    AREA = "area"
    DONUT = "donut"
    SCATTER = "scatter"
    WATERFALL = "waterfall"
    HISTOGRAM = "histogram"
    TREEMAP = "treemap"
    HORIZONTAL_BAR = "horizontal_bar"


class DataShape(str, Enum):
    TIME_SERIES = "time_series"
    CATEGORICAL = "categorical"
    MATRIX = "matrix"
    SINGLE_METRIC = "single_metric"
    PART_OF_WHOLE = "part_of_whole"
    FLOW = "flow"


# ---------------------------------------------------------------------------
# Data Structures
# ---------------------------------------------------------------------------

@dataclass
class StatisticalProfile:
    """Complete statistical summary of a 1-D numeric dataset."""
    mean: float = 0.0
    median: float = 0.0
    std: float = 0.0
    cv: float = 0.0
    skewness: float = 0.0
    kurtosis: float = 0.0
    min_val: float = 0.0
    max_val: float = 0.0
    q1: float = 0.0
    q3: float = 0.0
    iqr: float = 0.0
    outlier_count: int = 0
    outlier_ratio: float = 0.0
    has_negative: bool = False
    negative_ratio: float = 0.0
    zero_count: int = 0
    range_span: float = 0.0
    data_points: int = 0
    unique_ratio: float = 0.0


@dataclass
class AxisConfig:
    scale: ScaleType = ScaleType.LINEAR
    label: str = ""
    tick_format: str = ".1f"
    range_min: Optional[float] = None
    range_max: Optional[float] = None
    log_base: Optional[int] = None
    invert: bool = False


@dataclass
class ColorConfig:
    cmap_name: str = "viridis"
    center: Optional[float] = None
    vmin: Optional[float] = None
    vmax: Optional[float] = None
    diverging: bool = False
    intensity: float = 1.0
    highlight_indices: List[int] = field(default_factory=list)


@dataclass
class LabelConfig:
    show_values: bool = True
    format_str: str = ".1f"
    rotation: int = 0
    max_labels: int = 20
    truncate_length: int = 15
    font_size: int = 10


@dataclass
class AnnotationItem:
    text: str = ""
    x: float = 0.0
    y: float = 0.0
    style: str = "arrow"
    color: str = "#FFFFFF"
    fontsize: int = 11


@dataclass
class ChartSpec:
    chart_type: ChartType = ChartType.BAR
    title: str = ""
    subtitle: str = ""
    x_axis: AxisConfig = field(default_factory=AxisConfig)
    y_axis: AxisConfig = field(default_factory=AxisConfig)
    color: ColorConfig = field(default_factory=ColorConfig)
    labels: LabelConfig = field(default_factory=LabelConfig)
    annotations: List[AnnotationItem] = field(default_factory=list)
    figsize: Tuple[int, int] = (12, 7)
    dark_theme: bool = True
    metadata: Dict[str, Any] = field(default_factory=dict)


# ---------------------------------------------------------------------------
# Layer 1: Statistical Analysis & Auto-Scale/Color/Axis/Label
# ---------------------------------------------------------------------------

class StatisticalAnalyzer:
    """Computes a full StatisticalProfile from raw numeric data."""

    def analyze(self, data: List[float]) -> StatisticalProfile:
        """Analyze a flat list of numbers.

        Args:
            data: List of numeric values.

        Returns:
            StatisticalProfile with all fields populated.
        """
        if not data:
            return StatisticalProfile()

        arr = np.asarray(data, dtype=np.float64)
        arr = arr[np.isfinite(arr)]
        n = len(arr)
        if n == 0:
            return StatisticalProfile()

        mean = float(np.mean(arr))
        median = float(np.median(arr))
        std = float(np.std(arr, ddof=1)) if n > 1 else 0.0
        cv = abs(std / mean) if mean != 0 else 0.0

        # Skewness (Fisher)
        if n > 2 and std > 0:
            skewness = float(np.mean(((arr - mean) / std) ** 3))
        else:
            skewness = 0.0

        # Excess kurtosis
        if n > 3 and std > 0:
            kurtosis = float(np.mean(((arr - mean) / std) ** 4) - 3.0)
        else:
            kurtosis = 0.0

        q1 = float(np.percentile(arr, 25))
        q3 = float(np.percentile(arr, 75))
        iqr = q3 - q1
        min_val = float(np.min(arr))
        max_val = float(np.max(arr))

        lower_fence = q1 - 1.5 * iqr
        upper_fence = q3 + 1.5 * iqr
        outlier_mask = (arr < lower_fence) | (arr > upper_fence)
        outlier_count = int(np.sum(outlier_mask))

        neg_mask = arr < 0
        negative_count = int(np.sum(neg_mask))
        unique_count = len(np.unique(arr))

        return StatisticalProfile(
            mean=mean,
            median=median,
            std=std,
            cv=cv,
            skewness=skewness,
            kurtosis=kurtosis,
            min_val=min_val,
            max_val=max_val,
            q1=q1,
            q3=q3,
            iqr=iqr,
            outlier_count=outlier_count,
            outlier_ratio=outlier_count / n if n else 0.0,
            has_negative=bool(negative_count > 0),
            negative_ratio=negative_count / n if n else 0.0,
            zero_count=int(np.sum(arr == 0)),
            range_span=max_val - min_val,
            data_points=n,
            unique_ratio=unique_count / n if n else 0.0,
        )


class ScaleSelector:
    """Decides the best axis scale for a given statistical profile."""

    def select(self, profile: StatisticalProfile) -> ScaleType:
        if profile.data_points == 0:
            return ScaleType.LINEAR
        if profile.cv > 3.0 and profile.min_val > 0:
            return ScaleType.LOG
        if profile.has_negative and abs(profile.skewness) < 1.0:
            return ScaleType.DIVERGING
        if profile.cv > 2.0 and profile.has_negative:
            return ScaleType.SYMLOG
        return ScaleType.LINEAR


class ColorMapper:
    """Selects a colour-map configuration based on data profile and chart type."""

    def select(self, profile: StatisticalProfile, chart_type: ChartType) -> ColorConfig:
        cfg = ColorConfig()

        scale = ScaleSelector().select(profile)
        if scale == ScaleType.DIVERGING:
            cfg.cmap_name = "RdBu_r"
            cfg.center = 0.0
            cfg.diverging = True
        elif chart_type == ChartType.HEATMAP:
            cfg.cmap_name = "YlOrRd"
        elif profile.has_negative and profile.negative_ratio > 0.3:
            cfg.cmap_name = "RdYlGn"
            cfg.diverging = True
            cfg.center = 0.0
        else:
            cfg.cmap_name = "viridis"

        # Clip outlier-safe vmin / vmax
        if profile.iqr > 0:
            cfg.vmin = max(profile.min_val, profile.q1 - 1.5 * profile.iqr)
            cfg.vmax = min(profile.max_val, profile.q3 + 1.5 * profile.iqr)
        else:
            cfg.vmin = profile.min_val
            cfg.vmax = profile.max_val

        return cfg


class AxisConfigurator:
    """Builds an AxisConfig for a given axis (x or y)."""

    _SI = [(1_000_000_000, "B"), (1_000_000, "M"), (1_000, "K")]

    def configure(
        self,
        profile: StatisticalProfile,
        scale: ScaleType,
        axis: str = "y",
    ) -> AxisConfig:
        cfg = AxisConfig(scale=scale, label=axis)

        if scale == ScaleType.LOG:
            cfg.log_base = 10
            cfg.tick_format = ".1e" if profile.range_span > 1000 else ".0f"
        elif scale == ScaleType.DIVERGING:
            bound = max(abs(profile.min_val), abs(profile.max_val))
            cfg.range_min = -bound
            cfg.range_max = bound
            cfg.tick_format = "+.1f"
        else:
            cfg.tick_format = self._auto_format(profile)

        return cfg

    def _auto_format(self, p: StatisticalProfile) -> str:
        abs_max = max(abs(p.min_val), abs(p.max_val)) if p.data_points else 0
        if abs_max >= 1_000_000_000:
            return ".2s"
        if abs_max >= 1_000_000:
            return ".2s"
        if abs_max >= 1_000:
            return ",.0f"
        if p.range_span < 1 and p.range_span > 0:
            return ".3f"
        return ".1f"


class LabelDensityOptimizer:
    """Chooses label display strategy based on data density."""

    def optimize(
        self,
        data_points: int,
        chart_type: ChartType,
        figsize: Tuple[int, int] = (12, 7),
    ) -> LabelConfig:
        cfg = LabelConfig()

        if data_points < 10:
            cfg.show_values = True
            cfg.font_size = 11
            cfg.rotation = 0
            cfg.max_labels = data_points
        elif data_points <= 20:
            cfg.show_values = True
            cfg.font_size = 10
            cfg.rotation = 45
            cfg.max_labels = data_points
        elif data_points <= 50:
            cfg.show_values = False
            cfg.font_size = 9
            cfg.rotation = 45
            cfg.max_labels = data_points // 2
        else:
            cfg.show_values = False
            cfg.font_size = 8
            cfg.rotation = 90
            cfg.max_labels = data_points // 5
            cfg.truncate_length = 10

        if chart_type in (ChartType.BAR, ChartType.HORIZONTAL_BAR):
            cfg.show_values = True
        if chart_type == ChartType.HEATMAP and data_points < 100:
            cfg.show_values = True

        return cfg


class OutlierHandler:
    """Determines how outliers should be treated in the visualization."""

    def handle(
        self,
        data: List[float],
        profile: StatisticalProfile,
    ) -> Dict[str, Any]:
        """Return outlier handling strategy.

        Returns:
            Dict with keys: clip_min, clip_max, outlier_indices, strategy.
        """
        if profile.data_points == 0:
            return {"clip_min": 0.0, "clip_max": 0.0, "outlier_indices": [], "strategy": "none"}

        arr = np.asarray(data, dtype=np.float64)
        lower = profile.q1 - 1.5 * profile.iqr
        upper = profile.q3 + 1.5 * profile.iqr
        indices = [int(i) for i in np.where((arr < lower) | (arr > upper))[0]]

        if profile.outlier_ratio > 0.1:
            strategy = "log"
        elif profile.outlier_ratio > 0.02:
            strategy = "clip"
        else:
            strategy = "none"

        return {
            "clip_min": float(lower),
            "clip_max": float(upper),
            "outlier_indices": indices,
            "strategy": strategy,
        }


# ---------------------------------------------------------------------------
# Layer 2: KPI Detection & Chart Type Selection
# ---------------------------------------------------------------------------

class KPIDetector:
    """Infers domain-specific KPI characteristics from column names and values."""

    _FINANCIAL = {
        "btc", "price", "rate", "yield", "return",
        "stock", "index", "fund", "etf", "bond",
        "乖離", "騰落", "利回り", "株価", "為替", "時価", "配当",
    }
    _PERCENTAGE = {"%", "率", "ratio", "rate", "percent", "乖離率", "騰落率", "割合"}
    _CURRENCY = {"円", "ドル", "$", "¥", "usd", "jpy", "price", "価格", "金額"}
    _GROWTH = {"成長", "growth", "変化", "change", "前年比", "前月比", "yoy", "mom", "増減"}

    def detect(
        self,
        column_names: List[str],
        data_shape: DataShape,
        values: List[Any],
    ) -> Dict[str, Any]:
        joined = " ".join(column_names).lower()

        is_financial = any(k in joined for k in self._FINANCIAL)
        is_percentage = any(k in joined for k in self._PERCENTAGE)
        is_currency = any(k in joined for k in self._CURRENCY)
        is_growth_rate = any(k in joined for k in self._GROWTH)

        kpi_type = "generic"
        if is_financial:
            kpi_type = "financial"
        elif is_percentage:
            kpi_type = "percentage"
        elif is_currency:
            kpi_type = "currency"
        elif is_growth_rate:
            kpi_type = "growth"

        return {
            "kpi_type": kpi_type,
            "is_financial": is_financial,
            "is_percentage": is_percentage,
            "is_currency": is_currency,
            "is_growth_rate": is_growth_rate,
        }


class ChartTypeSelector:
    """Picks the optimal chart type via decision tree."""

    def select(
        self,
        data_shape: DataShape,
        kpi: Dict[str, Any],
        profile: StatisticalProfile,
        n_categories: int = 0,
        n_series: int = 1,
    ) -> ChartType:
        # Financial decision tree
        if kpi.get("is_financial"):
            if data_shape == DataShape.TIME_SERIES:
                return ChartType.AREA if n_series == 1 else ChartType.LINE
            if data_shape == DataShape.MATRIX:
                return ChartType.HEATMAP

        if kpi.get("is_percentage") and profile.has_negative:
            return ChartType.HORIZONTAL_BAR

        if kpi.get("is_growth_rate") and data_shape == DataShape.CATEGORICAL:
            return ChartType.BAR

        # General decision tree
        if data_shape == DataShape.PART_OF_WHOLE:
            return ChartType.DONUT if n_categories <= 7 else ChartType.TREEMAP

        if data_shape == DataShape.CATEGORICAL:
            if n_categories > 15:
                return ChartType.HORIZONTAL_BAR
            if n_series > 1:
                return ChartType.GROUPED_BAR
            return ChartType.BAR

        if data_shape == DataShape.TIME_SERIES:
            if n_series == 1:
                return ChartType.LINE
            if n_series <= 5:
                return ChartType.LINE
            return ChartType.HEATMAP

        if data_shape == DataShape.MATRIX:
            return ChartType.HEATMAP

        if n_series == 2 and data_shape != DataShape.SINGLE_METRIC:
            return ChartType.SCATTER

        if data_shape == DataShape.SINGLE_METRIC:
            return ChartType.BAR

        return ChartType.BAR


# ---------------------------------------------------------------------------
# Layer 3: X/Twitter Impact Optimization
# ---------------------------------------------------------------------------

class ImpactDetector:
    """Finds extreme values and generates talking-point summaries."""

    def detect(
        self,
        profile: StatisticalProfile,
        kpi: Dict[str, Any],
    ) -> Dict[str, Any]:
        if profile.data_points == 0:
            return self._empty()

        has_extreme = False
        extreme_direction = "mixed"
        magnitude = 0.0

        if profile.std > 0:
            z_max = (profile.max_val - profile.mean) / profile.std
            z_min = (profile.min_val - profile.mean) / profile.std

            if abs(z_max) > 2 or abs(z_min) > 2:
                has_extreme = True
                magnitude = max(abs(z_max), abs(z_min))
                if abs(z_max) >= abs(z_min):
                    extreme_direction = "up"
                else:
                    extreme_direction = "down"

        trend = self._simple_trend(profile)
        talking_points = self._build_talking_points(profile, kpi)

        return {
            "has_extreme": has_extreme,
            "extreme_direction": extreme_direction,
            "magnitude": magnitude,
            "trend": trend,
            "talking_points": talking_points,
        }

    @staticmethod
    def _empty() -> Dict[str, Any]:
        return {
            "has_extreme": False,
            "extreme_direction": "mixed",
            "magnitude": 0.0,
            "trend": "flat",
            "talking_points": [],
        }

    @staticmethod
    def _simple_trend(profile: StatisticalProfile) -> str:
        if profile.skewness > 0.5:
            return "up"
        if profile.skewness < -0.5:
            return "down"
        return "flat"

    @staticmethod
    def _build_talking_points(
        profile: StatisticalProfile,
        kpi: Dict[str, Any],
    ) -> List[str]:
        pts: List[str] = []
        fmt = ",.2f" if kpi.get("is_currency") else ".2f"
        pts.append(f"平均: {profile.mean:{fmt}}")
        pts.append(f"最大: {profile.max_val:{fmt}}")
        pts.append(f"最小: {profile.min_val:{fmt}}")
        if profile.outlier_count:
            pts.append(f"外れ値: {profile.outlier_count}件")
        return pts


class TitleGenerator:
    """Produces impact-oriented titles and subtitles (Japanese friendly)."""

    def generate(
        self,
        kpi: Dict[str, Any],
        impact: Dict[str, Any],
        data_context: Dict[str, Any],
    ) -> Tuple[str, str]:
        metric = data_context.get("metric_name", "指標")
        period = data_context.get("period", "")

        # Title
        if impact.get("has_extreme"):
            direction = impact.get("extreme_direction", "mixed")
            if direction == "up":
                title = f"{metric} が急騰"
            elif direction == "down":
                title = f"{metric} が急落"
            else:
                title = f"{metric} に大きな変動"
        elif impact.get("trend") == "up":
            title = f"{metric} 上昇傾向"
        elif impact.get("trend") == "down":
            title = f"{metric} 下降傾向"
        else:
            title = f"{metric}の推移" if period else f"{metric}"

        if period:
            title += f" ({period})"

        # Subtitle
        pts = impact.get("talking_points", [])
        subtitle = " | ".join(pts[:4]) if pts else ""

        return title, subtitle


class AnnotationPlacer:
    """Places annotations on extreme or notable data points."""

    def place(
        self,
        data: List[float],
        labels: List[str],
        profile: StatisticalProfile,
        chart_type: ChartType,
    ) -> List[AnnotationItem]:
        if not data:
            return []

        arr = np.asarray(data, dtype=np.float64)
        annotations: List[AnnotationItem] = []
        style = "box" if chart_type == ChartType.SCATTER else "arrow"

        # Max
        idx_max = int(np.argmax(arr))
        lbl_max = labels[idx_max] if idx_max < len(labels) else str(idx_max)
        annotations.append(AnnotationItem(
            text=f"Max: {arr[idx_max]:.2f} ({lbl_max})",
            x=float(idx_max),
            y=float(arr[idx_max]),
            style=style,
            color="#00FF88",
        ))

        # Min
        idx_min = int(np.argmin(arr))
        if idx_min != idx_max:
            lbl_min = labels[idx_min] if idx_min < len(labels) else str(idx_min)
            annotations.append(AnnotationItem(
                text=f"Min: {arr[idx_min]:.2f} ({lbl_min})",
                x=float(idx_min),
                y=float(arr[idx_min]),
                style=style,
                color="#FF4444",
            ))

        # Latest (time series)
        if chart_type in (ChartType.LINE, ChartType.AREA) and len(arr) > 2:
            idx_last = len(arr) - 1
            if idx_last not in (idx_max, idx_min):
                lbl_last = labels[idx_last] if idx_last < len(labels) else str(idx_last)
                annotations.append(AnnotationItem(
                    text=f"Latest: {arr[idx_last]:.2f} ({lbl_last})",
                    x=float(idx_last),
                    y=float(arr[idx_last]),
                    style=style,
                    color="#4488FF",
                ))

        # Few outliers
        if 0 < profile.outlier_count <= 3:
            lower = profile.q1 - 1.5 * profile.iqr
            upper = profile.q3 + 1.5 * profile.iqr
            for i, v in enumerate(arr):
                if (v < lower or v > upper) and i not in (idx_max, idx_min):
                    lbl = labels[i] if i < len(labels) else str(i)
                    annotations.append(AnnotationItem(
                        text=f"Outlier: {v:.2f} ({lbl})",
                        x=float(i),
                        y=float(v),
                        style=style,
                        color="#FFAA00",
                    ))

        return annotations


class ColorIntensifier:
    """Boosts colour intensity for impactful visualizations."""

    def intensify(
        self,
        color_config: ColorConfig,
        impact: Dict[str, Any],
    ) -> ColorConfig:
        cfg = ColorConfig(
            cmap_name=color_config.cmap_name,
            center=color_config.center,
            vmin=color_config.vmin,
            vmax=color_config.vmax,
            diverging=color_config.diverging,
            intensity=color_config.intensity,
            highlight_indices=list(color_config.highlight_indices),
        )

        if impact.get("has_extreme"):
            cfg.intensity = min(cfg.intensity * 1.3, 2.0)

        if impact.get("magnitude", 0) > 3.0:
            # Add extreme-point highlighting (indices derived from outliers)
            pass  # highlight_indices populated by OutlierHandler

        direction = impact.get("extreme_direction", "mixed")
        if direction == "down" and not cfg.diverging:
            cfg.cmap_name = "Reds"
        elif direction == "up" and not cfg.diverging:
            cfg.cmap_name = "Greens"

        return cfg


class TrendLineDecider:
    """Decides whether to overlay a trend line and its parameters."""

    def should_add(
        self,
        chart_type: ChartType,
        profile: StatisticalProfile,
        data_shape: DataShape,
        values: Optional[List[float]] = None,
    ) -> Dict[str, Any]:
        result: Dict[str, Any] = {
            "add_trendline": False,
            "trendline_type": "none",
            "window": 0,
        }

        if (
            chart_type in (ChartType.LINE, ChartType.AREA)
            and data_shape == DataShape.TIME_SERIES
            and profile.data_points > 10
        ):
            window = max(3, profile.data_points // 5)
            result.update(add_trendline=True, trendline_type="moving_avg", window=window)
            return result

        if chart_type == ChartType.SCATTER and values and len(values) >= 4:
            arr = np.asarray(values, dtype=np.float64)
            # Split into two halves as proxy for x/y
            half = len(arr) // 2
            x_part = arr[:half]
            y_part = arr[half : half + len(x_part)]
            if len(x_part) > 1 and np.std(x_part) > 0 and np.std(y_part) > 0:
                corr = float(np.corrcoef(x_part, y_part)[0, 1])
                if abs(corr) > 0.5:
                    result.update(add_trendline=True, trendline_type="linear", window=0)

        return result


# ---------------------------------------------------------------------------
# Integration Pipeline
# ---------------------------------------------------------------------------

class DataVizPipeline:
    """End-to-end pipeline: raw data -> ChartSpec."""

    def __init__(self) -> None:
        self.analyzer = StatisticalAnalyzer()
        self.scale_selector = ScaleSelector()
        self.color_mapper = ColorMapper()
        self.axis_configurator = AxisConfigurator()
        self.label_optimizer = LabelDensityOptimizer()
        self.outlier_handler = OutlierHandler()
        self.kpi_detector = KPIDetector()
        self.chart_selector = ChartTypeSelector()
        self.impact_detector = ImpactDetector()
        self.title_generator = TitleGenerator()
        self.annotation_placer = AnnotationPlacer()
        self.color_intensifier = ColorIntensifier()
        self.trendline_decider = TrendLineDecider()

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def run(
        self,
        data: Dict[str, Any],
        column_names: Optional[List[str]] = None,
        data_shape: Optional[DataShape] = None,
        data_context: Optional[Dict[str, Any]] = None,
    ) -> ChartSpec:
        """Execute the full optimization pipeline.

        Args:
            data: Dict with keys ``values``, ``labels``, ``series_names``,
                  ``time_index``.
            column_names: Header names used for KPI detection.
            data_shape: Explicit shape hint; auto-inferred when *None*.
            data_context: Optional metadata (metric_name, period, source, unit).

        Returns:
            Fully populated ChartSpec.
        """
        column_names = column_names or []
        data_context = data_context or {}

        values = data.get("values", [])
        labels = data.get("labels", [])
        series_names = data.get("series_names", [])
        time_index = data.get("time_index", [])

        flat = self._flatten(values)

        # 1. Statistical analysis
        profile = self.analyzer.analyze(flat)

        # 2. Scale selection
        scale = self.scale_selector.select(profile)

        # 3. KPI detection
        combined_names = list(column_names)
        if data_context.get("metric_name"):
            combined_names.append(data_context["metric_name"])
        if data_context.get("unit"):
            combined_names.append(data_context["unit"])
        kpi = self.kpi_detector.detect(combined_names, data_shape or DataShape.CATEGORICAL, flat)

        # 4. Infer DataShape
        if data_shape is None:
            data_shape = self._infer_shape(values, time_index, labels, series_names)

        # 5. Chart type
        n_categories = len(labels) if labels else profile.data_points
        n_series = max(1, len(series_names))
        chart_type = self.chart_selector.select(data_shape, kpi, profile, n_categories, n_series)

        # 6. Color
        color_cfg = self.color_mapper.select(profile, chart_type)

        # 7. Axes
        y_axis = self.axis_configurator.configure(profile, scale, axis="y")
        x_scale = ScaleType.LINEAR
        x_axis = self.axis_configurator.configure(
            StatisticalProfile(data_points=n_categories),
            x_scale,
            axis="x",
        )

        # 8. Labels
        label_cfg = self.label_optimizer.optimize(n_categories, chart_type, (12, 7))

        # 9. Outlier handling
        outlier_info = self.outlier_handler.handle(flat, profile)

        # 10. Impact
        impact = self.impact_detector.detect(profile, kpi)

        # 11. Title
        title, subtitle = self.title_generator.generate(kpi, impact, data_context)

        # 12. Annotations
        ann_labels = labels if labels else [str(i) for i in range(len(flat))]
        annotations = self.annotation_placer.place(flat, ann_labels, profile, chart_type)

        # 13. Color intensification
        color_cfg = self.color_intensifier.intensify(color_cfg, impact)
        if outlier_info["outlier_indices"]:
            color_cfg.highlight_indices = outlier_info["outlier_indices"]

        # 14. Trendline
        trendline = self.trendline_decider.should_add(chart_type, profile, data_shape, flat)

        # 15. Assemble
        spec = ChartSpec(
            chart_type=chart_type,
            title=title,
            subtitle=subtitle,
            x_axis=x_axis,
            y_axis=y_axis,
            color=color_cfg,
            labels=label_cfg,
            annotations=annotations,
            figsize=(12, 7),
            dark_theme=True,
            metadata={
                "profile": asdict(profile),
                "kpi": kpi,
                "outlier": outlier_info,
                "trendline": trendline,
                "data_shape": data_shape.value,
                "impact": impact,
            },
        )
        return spec

    # ------------------------------------------------------------------
    # Serialization
    # ------------------------------------------------------------------

    def to_dict(self, spec: ChartSpec) -> Dict[str, Any]:
        """Convert a ChartSpec into a JSON-serializable dict.

        Args:
            spec: The chart specification to serialize.

        Returns:
            Plain dict suitable for ``json.dumps``.
        """
        d = asdict(spec)
        # Enum values → strings
        d["chart_type"] = spec.chart_type.value
        d["x_axis"]["scale"] = spec.x_axis.scale.value
        d["y_axis"]["scale"] = spec.y_axis.scale.value
        return d

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------

    @staticmethod
    def _flatten(values: Any) -> List[float]:
        """Flatten nested lists / matrices into a 1-D float list."""
        if not values:
            return []
        try:
            arr = np.asarray(values, dtype=np.float64)
        except (ValueError, TypeError):
            # Mixed types — attempt element-wise
            flat: List[float] = []
            for v in values:
                if isinstance(v, (list, tuple, np.ndarray)):
                    flat.extend(float(x) for x in v if _is_numeric(x))
                elif _is_numeric(v):
                    flat.append(float(v))
            return flat
        return arr.ravel().tolist()

    @staticmethod
    def _infer_shape(
        values: Any,
        time_index: List[Any],
        labels: List[Any],
        series_names: List[Any],
    ) -> DataShape:
        if time_index:
            return DataShape.TIME_SERIES
        if isinstance(values, list) and values and isinstance(values[0], (list, tuple)):
            return DataShape.MATRIX
        if labels:
            return DataShape.CATEGORICAL
        if isinstance(values, list) and len(values) == 1:
            return DataShape.SINGLE_METRIC
        return DataShape.CATEGORICAL


# ---------------------------------------------------------------------------
# Module-level helpers
# ---------------------------------------------------------------------------

def _is_numeric(v: Any) -> bool:
    """Return True if *v* can be losslessly cast to float."""
    if isinstance(v, (int, float, np.integer, np.floating)):
        return True
    try:
        float(v)
        return True
    except (ValueError, TypeError):
        return False


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def main() -> None:
    """Read JSON from stdin or file, run pipeline, emit ChartSpec JSON."""
    if len(sys.argv) > 1:
        path = sys.argv[1]
        with open(path, encoding="utf-8") as fh:
            payload = json.load(fh)
    else:
        payload = json.load(sys.stdin)

    data = payload.get("data", payload)
    column_names = payload.get("column_names")
    data_shape_raw = payload.get("data_shape")
    data_context = payload.get("data_context")

    ds = DataShape(data_shape_raw) if data_shape_raw else None

    pipeline = DataVizPipeline()
    spec = pipeline.run(data, column_names=column_names, data_shape=ds, data_context=data_context)
    result = pipeline.to_dict(spec)

    json.dump(result, sys.stdout, ensure_ascii=False, indent=2)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
